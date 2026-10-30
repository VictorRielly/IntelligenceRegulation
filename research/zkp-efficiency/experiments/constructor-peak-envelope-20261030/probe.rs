//! Source-derived allocation skeleton only. No hashes, NTT, random masks,
//! transcript, PCS or native constructors are executed by this executable.
use std::alloc::{GlobalAlloc,Layout,System};
use std::sync::atomic::{AtomicUsize,Ordering::SeqCst};
static LIVE:AtomicUsize=AtomicUsize::new(0);
static PEAK:AtomicUsize=AtomicUsize::new(0);
struct Meter;
unsafe impl GlobalAlloc for Meter {
 unsafe fn alloc(&self,l:Layout)->*mut u8 {let p=System.alloc(l);if !p.is_null(){let n=LIVE.fetch_add(l.size(),SeqCst)+l.size();PEAK.fetch_max(n,SeqCst);}p}
 unsafe fn dealloc(&self,p:*mut u8,l:Layout){System.dealloc(p,l);LIVE.fetch_sub(l.size(),SeqCst);}
 unsafe fn realloc(&self,p:*mut u8,l:Layout,n:usize)->*mut u8 {let q=System.realloc(p,l,n);if !q.is_null(){let cur=if n>=l.size(){LIVE.fetch_add(n-l.size(),SeqCst)+n-l.size()}else{LIVE.fetch_sub(l.size()-n,SeqCst)-(l.size()-n)};PEAK.fetch_max(cur,SeqCst);}q}
}
#[global_allocator]static ALLOC:Meter=Meter;
type Digest=[u8;32];
struct Owner {data:Vec<u64>,pads:Vec<u64>,salts:Vec<Digest>,encoded:Vec<u64>,tree:Vec<Vec<Digest>>}
#[derive(Clone,Copy)]struct Obs {live:usize,overhead:usize}
fn snap(out:&mut [Obs;10],i:usize,base:usize,overhead:usize){out[i]=Obs{live:LIVE.load(SeqCst)-base,overhead};}
fn constructor(rows:usize,n:usize,q:usize,out:&mut [Obs;10],base:usize)->Owner {
 let nn=4*n;
 let data=vec![0u64;rows*n];snap(out,0,base,0);
 let pads=vec![0u64;rows*q];let salts=vec![[0u8;32];nn];let pows=vec![0u64;nn];snap(out,1,base,0);
 let mut encoded=Vec::<u64>::with_capacity(rows*nn);
 {let coeffs=data[..n].to_vec();std::hint::black_box(&coeffs);snap(out,2,base,0);}
 // Allocation contents are irrelevant; initialized zeros prevent UB.
 encoded.resize(rows*nn,0);snap(out,3,base,0);
 let leaves={
  let leaves=vec![[0u8;32];nn];
  {let w=64usize.min(nn);let bufs:Vec<Vec<u8>>=(0..w).map(|_|Vec::with_capacity(rows*8)).collect();
   snap(out,4,base,bufs.capacity()*std::mem::size_of::<Vec<u8>>());std::hint::black_box(&bufs);}
  leaves
 };snap(out,5,base,0);
 let salted:Vec<Digest>=leaves.iter().zip(salts.iter()).map(|_|[0u8;32]).collect();snap(out,6,base,0);
 let mut levels=vec![salted];
 while levels.last().unwrap().len()>1 {let next=vec![[0u8;32];levels.last().unwrap().len()/2];levels.push(next);}
 let headers=levels.capacity()*std::mem::size_of::<Vec<Digest>>();snap(out,7,base,headers);
 // leaves and pows drop on returning; ownership of the other buffers moves.
 std::hint::black_box((&pows,&leaves));
 Owner{data,pads,salts,encoded,tree:levels}
}
mod accuracy_precision {#[derive(Clone,Copy,PartialEq,Eq)]pub enum Stack{Legacy,LowH24,Other}}
mod native {
 include!("metadata.rs");
 pub fn measure(v:&[usize])->Vec<usize>{
  let sh=Shape{tokens:v[0],width:v[1],hidden:v[2],q_heads:v[3],head_dim:v[4],kv_heads:v[5],log_cols:v[6],dd_cap:v[7],norm_wrho:v[8] as u32,wrho_s:v[9] as u32,stack:if v[10]==0{super::accuracy_precision::Stack::Legacy}else{super::accuracy_precision::Stack::LowH24},t_pad:v[0].next_power_of_two(),d_pad:v[1].next_power_of_two(),h_pad:v[3].next_power_of_two(),f_pad:v[2].next_power_of_two()};
  let doms=[Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F,Dom::Dd];
  let looked:usize=doms.iter().filter(|d|**d!=Dom::Dd||sh.dd_cap>0).map(|d|sh.lookups_per_position(*d)*sh.size(*d)).sum();
  let mask_coeffs:usize=sh.slots()[..sh.n_slots()].iter().map(|(n,e,d)|(n+e)*d+2).sum();
  vec![looked,sh.size(Dom::S),sh.size(Dom::F),sh.m_rows(),mask_coeffs,sh.n_slots()]
 }
}
use std::io::{self,Read};
fn main(){
 // Initialize stdout before any allocator-baseline observation.
 println!("SCOPE allocation-skeleton-not-crypto");
 let mut input=String::new();io::stdin().read_to_string(&mut input).unwrap();
 for line in input.lines(){let p:Vec<_>=line.split_whitespace().collect();let v:Vec<usize>=p[1..].iter().map(|x|x.parse().unwrap()).collect();print!("M {}",p[0]);for x in native::measure(&v){print!(" {}",x);}println!();}
 for rows in [1usize,3,31,65]{for n in [8usize,32,128]{for q in [1usize,4]{
  let base=LIVE.load(SeqCst);PEAK.store(base,SeqCst);let mut out=[Obs{live:0,overhead:0};10];
  let owner=constructor(rows,n,q,&mut out,base);
  let heads=owner.tree.capacity()*std::mem::size_of::<Vec<Digest>>();snap(&mut out,8,base,heads);
  std::hint::black_box(&owner);drop(owner);snap(&mut out,9,base,0);
  let peak=PEAK.load(SeqCst)-base;
  for (stage,o) in out.iter().enumerate(){println!("A {} {} {} {} {} {} {}",rows,n,q,stage,o.live,o.overhead,peak);}
 }}}
}
