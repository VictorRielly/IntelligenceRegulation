#![allow(dead_code)]
#[path="native/zkp-core/src/field.rs"] mod field;
use field::{Fp,Fp2};
#[derive(Clone,Copy,Debug,PartialEq,Eq)] enum Dom{L,D,Q,Kv,S,F,Tab,Dd}
impl Dom{fn idx(self)->usize{self as usize}}
mod shape{
 use super::*;
 #[derive(Clone)] pub(crate) struct Shape{pub log_cols:usize,pub dd_cap:usize,pub logs:[usize;8],pub hs:[usize;8]}
 impl Shape{
  pub fn helpers(&self,d:Dom)->usize{self.hs[d.idx()]}
  pub fn log(&self,d:Dom)->usize{self.logs[d.idx()]}
  pub fn rows_of(&self,d:Dom)->usize{1usize<<self.log(d).saturating_sub(self.log_cols)}
 }
 include!("h_domains.rs");
}
use shape::Shape;
mod argument{pub const DD_LAPSE_OUT_OF_SUM:u8=4;pub fn dd_lapse(_:u8)->bool{false}}
#[derive(Clone,Debug)]struct Slice{offset:usize,log_size:u32}
#[derive(Clone,Debug)]struct ZPart{slice:Slice,coef:Fp2,point:Vec<Fp2>}
#[derive(Clone,Debug)]struct ZClaim{parts:Vec<ZPart>,value:Fp2}
#[derive(Clone,Debug,PartialEq)]struct ZKey{tail:Vec<Fp2>,c0:usize,len:usize}
#[derive(Clone,Copy,Debug,PartialEq,Eq)]enum Cm{A,H,In,Out}
struct Priv{cm:Cm,slices:Vec<(usize,Fp2)>,log:usize,coords:Vec<usize>,mask_row:usize,ext_round:usize}
enum Tab{Priv(Priv)}
fn rho(r:std::ops::Range<usize>)->Vec<usize>{r.collect()}
fn row_log(sh:&Shape,_cm:Cm)->usize{sh.log_cols}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn random(s:&mut u64)->Fp2{Fp2::new(Fp::new(next(s)),Fp::new(next(s)))}
#[derive(Clone)]struct Transcript{state:u64,draws:usize}
impl Transcript{fn challenge_fp2_vec(&mut self,n:usize)->Vec<Fp2>{self.draws+=n;(0..n).map(|_|random(&mut self.state)).collect()}}
include!("serial_eq.rs");
mod native{
 use super::*;
 include!("hids.rs");include!("h_offsets.rs");
 struct Layout{sh:Shape,ids:HIds,h_off:Vec<(usize,usize)>,h_mask_base:usize,h_prox:usize,h_rows:usize,sites:Vec<Vec<usize>>,prefix:Vec<usize>}
 impl Layout{
  fn shape(&self)->&Shape{&self.sh} fn hids(&self)->&HIds{&self.ids}
  fn h_planes(&self)->Vec<usize>{(0..self.ids.n_h()).collect()}
  fn h_site(&self,slot:usize,k:usize)->Result<usize,String>{if k>=self.sites[slot].len(){Err("site".into())}else{Ok(self.h_mask_base+2*(self.prefix[slot]+k))}}
 }
 struct B<'a>{lay:&'a Layout,slot:usize,hk:usize,tabs:Vec<Tab>}
 impl<'a>B<'a>{fn push(&mut self,t:Tab)->usize{let i=self.tabs.len();self.tabs.push(t);i}
 }
 include!("h_builder.rs");
 include!("builder.rs");include!("sum_claim.rs");include!("native_groups.rs");include!("native_audit.rs");include!("cases.rs");
 fn layout(sh:Shape)->Layout{
  let ids=HIds::new(&sh).unwrap();let(h_off,data)=offsets(&sh);let mut sites=vec![vec![];24];
  // Source B::h call order in argument.rs/argument_accuracy.rs. Each H
  // plane enters exactly one evaluation claim; native define is not run.
  for(slot,dom)in [(3,Dom::L),(14,Dom::D),(15,Dom::Q),(16,Dom::Kv),(17,Dom::S),(18,Dom::F)]{
   sites[slot]=(0..sh.helpers(dom)).map(|j|ids.helper(dom,j)).collect();
  }
  sites[17].push(ids.sexp());if sh.dd_cap>0{sites[17].push(ids.stuple());sites[23]=(0..sh.helpers(Dom::Dd)).map(|j|ids.helper(Dom::Dd,j)).collect();sites[23].push(ids.gdd());}
  sites[18].push(ids.fact());sites[19]=ids.table_helpers().to_vec();sites[20]=vec![ids.u()];
  let mut prefix=vec![0];for s in &sites{prefix.push(prefix.last().unwrap()+s.len());}
  let prox=data+2*prefix[24];Layout{sh,ids,h_off,h_mask_base:data,h_prox:prox,h_rows:prox+2,sites,prefix}
 }
 fn union(sets:&[Vec<bool>],range:std::ops::Range<usize>)->usize{(0..sets[0].len()).filter(|r|range.clone().any(|j|sets[j][*r])).count()}
 fn supports(claims:&[ZClaim],rows:usize,n:usize)->Vec<Vec<bool>>{
  let mut keys:Vec<(Vec<Fp2>,usize,usize)>=vec![];let mut sets:Vec<Vec<bool>>=vec![];
  for c in claims{let p=&c.parts[0];let ls=p.slice.log_size as usize;let key=(if p.point.is_empty(){vec![]}else{p.point[ls.saturating_sub(n.trailing_zeros()as usize)..].to_vec()},if (1<<ls)>=n{0}else{p.slice.offset%n},(1<<ls).min(n));
   let j=match keys.iter().position(|x|*x==key){Some(j)=>j,None=>{keys.push(key);sets.push(vec![false;rows]);keys.len()-1}};
   for p in &c.parts{for r in part_rows(p,n){sets[j][r]=true;}}
  }sets
 }
 pub fn run(){
  let start=std::time::Instant::now();let mut seed=202610290149;let(mut fixtures,mut coeffs,mut folds,mut restored,mut controls)=(0,0,0,0,0);let mut records=vec![];
  let mut cases=source_cases();
  for log in [1,3,5]{for dd in [0,1]{for mode in 0..3{
   let logs=std::array::from_fn(|i|log+(i%3));cases.push(Shape{log_cols:log,dd_cap:dd,logs,hs:[1,2,2,1,2,2,0,1]});
   // mode is consumed below from case index for independent corner fixtures.
   let _=mode;
  }}}
  for(case,sh)in cases.into_iter().enumerate(){let lay=layout(sh);let sh=&lay.sh;let n=1<<sh.log_cols;let rows=lay.h_rows;let mut claims=vec![];let mut plane_seen=vec![false;lay.ids.n_h()];let mut mask_seen=vec![];let mut descriptors=vec![];
   for slot in 0..24{let mut b=B{lay:&lay,slot,hk:0,tabs:vec![]};for p in &lay.sites[slot]{assert!(!plane_seen[*p]);plane_seen[*p]=true;b.h(*p).unwrap();}
    let point:Vec<_>=(0..32).map(|_|random(&mut seed)).collect();
    for t in b.tabs{let Tab::Priv(p)=t;let mut pt=point[..p.log].to_vec();if case>=2{match (case-2)%3{0=>pt.fill(Fp2::ZERO),1=>pt.fill(Fp2::ONE),_=>()}}
     let cd=random(&mut seed);let cm=random(&mut seed);mask_seen.push(p.mask_row);mask_seen.push(p.mask_row+1);descriptors.push(vec![slot,p.log,p.slices[0].0,p.slices[1].0,p.mask_row]);claims.push(build_claim(sh,&p,&pt,cd,cm,Fp2::ZERO));
    }
   }assert!(plane_seen.iter().all(|x|*x));assert_eq!(mask_seen,(lay.h_mask_base..lay.h_prox).collect::<Vec<_>>());
   let sum=logup_sum_claim(&lay);claims.push(sum);let u=lay.h_off[lay.ids.u()];let sites:Vec<_>=(lay.h_mask_base..lay.h_prox).collect();audit_claims(&claims,n,rows,&sites,Some([u.0/n,u.1/n]),lay.h_prox).unwrap();
   let mut sets=supports(&claims,rows,n);let groups=group_zclaims(&claims,rows,sh.log_cols as u32);assert_eq!(sets.len(),groups.len());
   let eval=sets.len()-1;for r in 0..lay.h_prox{assert_eq!(sets[..eval].iter().filter(|s|s[r]).count(),1,"evaluation partition");}
   assert_eq!(sets[eval].iter().filter(|x|**x).count(),lay.h_mask_base);for r in 0..rows{assert_eq!(sets[eval][r],r<lay.h_mask_base);}
   let mut tr=Transcript{state:20261029,draws:0};let(rhos,_)=zk_rhos(&groups,rows,&mut tr);sets.push(vec![true;rows]);assert_eq!(sets.len(),rhos.len());
   let mut numeric=vec![];for(j,rho)in rhos.iter().enumerate(){let nz=rho.iter().filter(|x|**x!=Fp2::ZERO).count();for r in 0..rows{assert!(sets[j][r]||rho[r]==Fp2::ZERO);}numeric.push(nz);}
   let visits:usize=(0..sets.len()).step_by(4).map(|j|union(&sets,j..(j+4).min(sets.len()))).sum();let baseline=((sets.len()+3)/4)*rows;
   // Differential against independent full-cube coefficients only at small geometry.
   if case>=2{let mut ki=vec![];let mut members=vec![];
    for c in &claims{let k=ref_key(&c.parts[0],n);let gi=match ki.iter().position(|x|*x==k){Some(i)=>i,None=>{ki.push(k);members.push(0);ki.len()-1}};let mi=members[gi];members[gi]+=1;let dense=dense(c,rows,n);for r in 0..rows{for col in 0..n{assert_eq!(rm(rr(groups[gi].1[mi].0[r]),rr(groups[gi].0[col])),dense[r*n+col]);coeffs+=1;}}}
    let data:Vec<_>=(0..rows*(n+3)).map(|_|random(&mut seed)).collect();for rho in &rhos{for col in 0..n+3{let a=(0..rows).fold(Fp2::ZERO,|a,r|a.add(rho[r].mul(data[r*(n+3)+col])));let b=(0..rows).filter(|r|rho[*r]!=Fp2::ZERO).fold((0,0),|a,r|ra(a,rm(rr(rho[r]),rr(data[r*(n+3)+col]))));assert_eq!(rr(a),b);folds+=1;}}
    // Physical dense-batch packing, then inverse scatter to original
    // opening order. All message AND pad columns remain in every output.
    let mut order:Vec<usize>=(0..rhos.len()).collect();let eval=rhos.len()-2;
    if rhos.len()>4{let mut top:Vec<usize>=(0..eval).collect();top.sort_by_key(|i|std::cmp::Reverse(sets[*i].iter().filter(|x|**x).count()));let hot=&top[..2];order=vec![hot[0],hot[1],eval,eval+1];order.extend((0..eval).filter(|i|!hot.contains(i)));}
    let mut original=vec![vec![(0,0);n+3];rhos.len()];let mut scattered=original.clone();
    for (g,rho) in rhos.iter().enumerate(){for col in 0..n+3{original[g][col]=(0..rows).fold((0,0),|a,r|ra(a,rm(rr(rho[r]),rr(data[r*(n+3)+col]))));}}
    for batch in order.chunks(4){for col in 0..n+3{let mut acc=vec![(0,0);batch.len()];for r in 0..rows{if batch.iter().all(|g|rhos[*g][r]==Fp2::ZERO){continue;}for (i,g) in batch.iter().enumerate(){if rhos[*g][r]!=Fp2::ZERO{acc[i]=ra(acc[i],rm(rr(rhos[*g][r]),rr(data[r*(n+3)+col])));}}}for(i,g)in batch.iter().enumerate(){scattered[*g][col]=acc[i];restored+=1;}}}
    assert_eq!(original,scattered);let mut bad=scattered.clone();bad.swap(0,rhos.len()-1);assert_ne!(original,bad);controls+=1;
    let mut bad=claims.clone();bad[0].parts[0].slice.offset=lay.h_prox*n;assert!(audit_claims(&bad,n,rows,&sites,Some([u.0/n,u.1/n]),lay.h_prox).is_err());controls+=1;
    let mut bad=claims.clone();let last=bad.len()-1;bad[last].parts[0].slice.offset=lay.h_mask_base*n;assert!(audit_claims(&bad,n,rows,&sites,Some([u.0/n,u.1/n]),lay.h_prox).is_err());controls+=1;
    let mut bad=claims.clone();bad[0].parts[1].slice.offset=bad[0].parts[0].slice.offset;assert_ne!(dense(&bad[0],rows,n),dense(&claims[0],rows,n));controls+=1;
    if sets.len()>4{assert!(visits>union(&sets,0..sets.len()));}else{assert_eq!(visits,union(&sets,0..sets.len()));}controls+=1;
   }
   if case<2{let lengths:Vec<_>=sets.iter().map(|s|s.iter().filter(|x|**x).count()).collect();let chunks:Vec<_>=(0..sets.len()).step_by(4).map(|j|union(&sets,j..(j+4).min(sets.len()))).collect();records.push(format!("{{\"dd\":{},\"rows\":{rows},\"data_rows\":{},\"sites\":{},\"groups\":{},\"rho_support_sizes\":{lengths:?},\"numeric_nonzeros\":{numeric:?},\"descriptors\":{descriptors:?},\"chunk_union_visits\":{chunks:?},\"baseline_visits\":{baseline},\"structural_visits\":{visits},\"baseline_bytes\":{},\"structural_bytes_upper\":{}}}",sh.dd_cap>0,lay.h_mask_base,mask_seen.len()/2,groups.len(),baseline*n*8,visits*n*8));}fixtures+=1;
  }
  println!("{{\"status\":\"PASS\",\"seed\":202610290149,\"fixtures\":{fixtures},\"independent_coefficients\":{coeffs},\"message_plus_pad_folds\":{folds},\"restored_order_values\":{restored},\"negative_controls\":{controls},\"profiles\":[{}],\"elapsed_s\":{},\"full_stack_proofs\":0,\"model_passes\":0,\"proved_positions\":0}}",records.join(","),start.elapsed().as_secs_f64());
 }
}
type Ref=(u64,u64);const P:u128=0xffffffff00000001;
fn ra(a:Ref,b:Ref)->Ref{(((a.0 as u128+b.0 as u128)%P)as u64,((a.1 as u128+b.1 as u128)%P)as u64)}
fn rs(a:Ref,b:Ref)->Ref{(((P+a.0 as u128-b.0 as u128)%P)as u64,((P+a.1 as u128-b.1 as u128)%P)as u64)}
fn rm(a:Ref,b:Ref)->Ref{let f=|x:u64,y:u64|((x as u128*y as u128)%P)as u64;ra((f(a.0,b.0),f(a.0,b.1)),(f(7,f(a.1,b.1)),f(a.1,b.0)))}
fn rr(a:Fp2)->Ref{(a.c0.0,a.c1.0)}
fn weight(p:&[Fp2],i:usize)->Ref{p.iter().enumerate().fold((1,0),|a,(j,x)|rm(a,if (i>>(p.len()-1-j))&1==1{rr(*x)}else{rs((1,0),rr(*x))}))}
fn dense(c:&ZClaim,rows:usize,n:usize)->Vec<Ref>{let mut out=vec![(0,0);rows*n];for p in &c.parts{for i in 0..1<<p.slice.log_size{let w=if p.point.is_empty(){(1,0)}else{weight(&p.point,i)};out[p.slice.offset+i]=ra(out[p.slice.offset+i],rm(rr(p.coef),w));}}out}
fn ref_key(p:&ZPart,n:usize)->(Vec<Ref>,usize,usize){let size=1<<p.slice.log_size;let len=size.min(n);let bits=len.trailing_zeros()as usize;(if p.point.is_empty(){vec![]}else{p.point[p.point.len()-bits..].iter().copied().map(rr).collect()},if size>=n{0}else{p.slice.offset%n},len)}
fn main(){native::run()}
