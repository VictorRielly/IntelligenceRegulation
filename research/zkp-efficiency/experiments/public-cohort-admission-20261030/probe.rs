mod accuracy_precision {#[derive(Clone,Copy,PartialEq,Eq)] pub enum Stack {Legacy,LowH24,Other}}
mod native {
include!("metadata.rs");
pub fn metadata(v:&[usize])->Vec<usize> {
 let sh=Shape{tokens:v[0],width:v[1],hidden:v[2],q_heads:v[3],head_dim:v[4],kv_heads:v[5],
 log_cols:v[6],dd_cap:v[7],norm_wrho:v[8] as u32,wrho_s:v[9] as u32,stack:if v[10]==0 {super::accuracy_precision::Stack::Legacy} else {super::accuracy_precision::Stack::LowH24},
 t_pad:v[0].next_power_of_two(),d_pad:v[1].next_power_of_two(),h_pad:v[3].next_power_of_two(),f_pad:v[2].next_power_of_two()};
 let (a,h)=sh.claim_sites();
 let ad:usize=sh.a_plane_doms().iter().map(|d|sh.rows_of(*d)).sum();
 let hd:usize=sh.h_plane_doms().iter().map(|d|2*sh.rows_of(*d)).sum();
 let ar=ad+2*a.iter().sum::<usize>()+2; let hr=hd+2*h.iter().sum::<usize>()+2;
 // Source-screened SC_SZC arm: three equality tables, causal mask, every
 // private site, and each applicable support. define itself is not run.
 let supports=usize::from(sh.pads(Dom::Ht))+usize::from(sh.pads(Dom::S));
 let k=4+a[SC_SZC]+h[SC_SZC]+supports;
 vec![ar,hr,sh.m_rows(),sh.log(Dom::S),k,a[SC_SZC],h[SC_SZC],supports,ad,hd]
}
}
use std::io::{self,Read};
fn main(){
 let mut s=String::new();io::stdin().read_to_string(&mut s).unwrap();
 for line in s.lines(){let p:Vec<_>=line.split_whitespace().collect();
  if p[0]=="M" {let v:Vec<usize>=p[2..].iter().map(|x|x.parse().unwrap()).collect();assert_eq!(v.len(),11);
   print!("M {}",p[1]);for x in native::metadata(&v){print!(" {}",x);}println!();
  } else if p[0]=="V" {let n:usize=p[2].parse().unwrap();let k:usize=p[3].parse().unwrap();
   assert!((1..=12).contains(&n)&&k<=32); // tiny allocations only
   let mut tables=vec![vec![[0u64;2];1usize<<n];k];
   for r in 0..=n {let len:usize=tables.iter().map(Vec::len).sum();let cap:usize=tables.iter().map(Vec::capacity).sum();
    println!("V {} {} {} {}",p[1],r,len*16,cap*16);
    if r<n {for tb in &mut tables {tb.truncate(tb.len()/2);}}
   }
   for tb in &mut tables {tb.clear();}
   println!("C {} {}",p[1],tables.iter().map(|v|v.capacity()*16).sum::<usize>());
  } else {panic!("mode");}
 }
}
