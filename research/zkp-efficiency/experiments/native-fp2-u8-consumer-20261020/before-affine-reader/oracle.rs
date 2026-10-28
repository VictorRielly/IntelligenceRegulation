//! Research harness. Pinned native field, pure extracted helper functions;
//! independently written resident fraction-tree/layer reference. No private proof.
#[path="source/native-field.rs"] mod field;
mod native_helpers;
use field::{Fp,Fp2,batch_inverse2_checked};
use std::io::{self,Read};
fn e(it:&mut std::str::SplitWhitespace<'_>)->Fp2 {
    Fp2::new(Fp::new(it.next().unwrap().parse().unwrap()),Fp::new(it.next().unwrap().parse().unwrap()))
}
fn emit(x:Fp2){ print!(" {} {}",x.c0.0,x.c1.0); }
fn term(v:&[Fp2],lam:Fp2)->Fp2 {v[0].mul(v[3]).add(v[2].mul(v[1])).add(lam.mul(v[1]).mul(v[3]))}
fn main(){
 let mut input=String::new();io::stdin().read_to_string(&mut input).unwrap();
 for line in input.lines(){
  let mut it=line.split_whitespace();let mode=it.next().unwrap();
  match mode {
   "H"=>{
    let a=e(&mut it);let g=e(&mut it);let cache=native_helpers::u8_denominator_inverses(a,g);
    print!("H");
    for tok in it {
     let v:i64=tok.parse().unwrap();
     match native_helpers::helper_one(v,a,g,&cache) {
      Ok(x)=>{print!(" OK");emit(x);},Err(_)=>print!(" ERR")
     }
    }println!();
   },
   "T"=>{
    let a=e(&mut it);let g=e(&mut it);
    let mut den:Vec<Fp2>=(0..256).map(|v|a.sub(Fp2::from_i64(v).add(g))).collect();
    if batch_inverse2_checked(&mut den).is_err(){println!("T ERR");continue;}
    print!("T OK");for x in den {emit(x);}println!();
   },
   "L"=>{
    let n:usize=it.next().unwrap().parse().unwrap();let d:usize=it.next().unwrap().parse().unwrap();let k=d-1;
    let lam=e(&mut it);let point:Vec<Fp2>=(0..k).map(|_|e(&mut it)).collect();
    let ch:Vec<Fp2>=(0..k).map(|_|e(&mut it)).collect();
    let mut level:Vec<(Fp2,Fp2)>=(0..n).map(|_|(e(&mut it),e(&mut it))).collect();
    assert!(level.iter().all(|(_,d)|!d.is_zero()));
    while level.len()>(1<<d){
     level=level.chunks_exact(2).map(|z|(z[0].0.mul(z[1].1).add(z[1].0.mul(z[0].1)),z[0].1.mul(z[1].1))).collect();
    }
    let m=level.len()/2;
    let mut planes:Vec<Vec<Fp2>>=(0..4).map(|c|(0..m).map(|j|{
     let z=level[2*j+c/2];if c%2==0{z.0}else{z.1}
    }).collect()).collect();
    let mut eq=Vec::new();
    for j in 0..m {
     let mut w=Fp2::ONE;
     for t in 0..k {w=w.mul(if j>>t&1==1{point[t]}else{Fp2::ONE.sub(point[t])});}eq.push(w);
    }planes.push(eq);
    print!("L");let mut active=m;
    for t in 0..k {
     for x in 0..4 {
      let x=Fp2::from_i64(x);let mut sum=Fp2::ZERO;
      for j in 0..active/2 {
       let vals:Vec<Fp2>=planes.iter().map(|v|v[2*j].add(x.mul(v[2*j+1].sub(v[2*j])))).collect();
       sum=sum.add(vals[4].mul(term(&vals,lam)));
      }emit(sum);
     }
     for v in &mut planes {for j in 0..active/2 {v[j]=v[2*j].add(ch[t].mul(v[2*j+1].sub(v[2*j])));}}
     active/=2;
    }
    let vals:Vec<Fp2>=planes.iter().map(|v|v[0]).collect();emit(vals[4].mul(term(&vals,lam)));
    for x in &vals[..4]{emit(*x);}println!();
   },
   _=>panic!("unknown research fixture")
  }
 }
}
