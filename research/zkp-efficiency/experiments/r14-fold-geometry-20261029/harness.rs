#![allow(dead_code)]
mod block {
    pub mod accuracy_precision { #[derive(Clone,Copy,PartialEq,Eq)] pub enum Stack { Legacy,LowH24 } }
    pub mod layout {
        #[derive(Clone,Copy,Debug,PartialEq,Eq)] pub enum Dom {T,Ht,L,D,Q,Kv,S,F,Tab,Dd}
        impl Dom {pub fn carries_h_planes(self)->bool{!matches!(self,Self::T|Self::Ht)}}
        pub fn domain_log_at(n:usize,h:bool,r:usize)->usize{if h{n.max(r)}else{n}}
        include!("constants.rs");
    }
    pub mod shape {
        use super::layout::*;
        pub const LIMBS_ISQRT:usize=3;pub const U8_LEN:usize=256;
        fn clog2(x:usize)->usize{(usize::BITS-(x-1).leading_zeros()) as usize}
        #[derive(Clone)] pub struct Shape {pub tokens:usize,pub width:usize,pub hidden:usize,pub log_cols:usize,pub dd_cap:usize,pub t_pad:usize,pub d_pad:usize,pub f_pad:usize,pub h_pad:usize,pub q_heads:usize,pub head_dim:usize,pub kv_heads:usize,pub ls:usize,pub legacy:bool}
        impl Shape {
            pub fn accuracy_stack(&self)->super::accuracy_precision::Stack{if self.legacy{super::accuracy_precision::Stack::Legacy}else{super::accuracy_precision::Stack::LowH24}}
            pub fn limbs_sigma_s(&self)->usize{self.ls}
            pub fn limbs_norm(&self)->usize{3}
            pub fn limbs_p(&self)->usize{2}
            pub fn norm_top_is_full_byte(&self)->bool{true}
            pub fn carries_pad_rule(&self)->bool{true}
            pub fn q_pad(&self)->usize{self.h_pad*self.head_dim}
        }
        include!("shape_methods.rs");
    }
    pub mod split_layout {include!("native_split.rs");}
}
use block::{shape::Shape,split_layout::{SplitLayout,probe_audit}};
fn make(t:usize,dd:bool,fe:usize)->Shape{Shape{tokens:t,width:3072,hidden:9216,log_cols:if t==128{14}else{15},dd_cap:if dd{32}else{0},t_pad:t,d_pad:4096,f_pad:16384,h_pad:32,q_heads:32,head_dim:128,kv_heads:8,ls:((t.trailing_zeros() as usize)+fe+7)/8,legacy:false}}
fn main(){
 let mut controls=0;
 for t in [128,256]{for dd in [false,true]{for fe in [9,12,16]{
  let b=make(t,dd,fe);let s=SplitLayout::new(&b,[2048,1024],[8192,1024]).unwrap();
  let mut bad=s.clone();bad.a[1].offset=0;assert!(probe_audit(&bad,&b).is_err());controls+=1;
  let mut bad=s.clone();bad.h.remove(0);assert!(probe_audit(&bad,&b).is_err());controls+=1;
  let mut bad=s.clone();bad.a_rows-=1;assert!(probe_audit(&bad,&b).is_err());controls+=1;
  let mut bad=s.clone();bad.slots[1].a_pairs[0]=bad.slots[0].a_pairs[0];assert!(probe_audit(&bad,&b).is_err());controls+=1;
  let mut bad=s.clone();bad.slots.pop();assert!(probe_audit(&bad,&b).is_err());controls+=1;
  for (d,f) in [([1024,1024],[8192,1024]),([1024,2048],[8192,1024]),([2048,1024],[4096,512]),([2000,1072],[8192,1024])]{assert!(SplitLayout::new(&b,d,f).is_err());controls+=1;}
  let mut short=b.clone();short.log_cols=19;assert!(SplitLayout::new(&short,[2048,1024],[8192,1024]).is_err());controls+=1;
  let mut old=b.clone();old.legacy=true;assert!(SplitLayout::new(&old,[2048,1024],[8192,1024]).is_err());controls+=1;
  print!("{{\"t\":{t},\"dd\":{dd},\"fe\":{fe},\"n\":{},\"a_data\":{},\"h_data\":{},\"a_rows\":{},\"h_rows\":{},\"m_rows\":{},\"endpoint\":[{},{},{}],\"planes\":[",s.n,s.a_data_rows,s.h_data_rows,s.a_rows,s.h_rows,s.m_rows,s.endpoint.data_rows,s.endpoint.external_rows,s.endpoint.internal_rows);
  let mut first=true;
  for (cm,ps) in [("A",&s.a),("H",&s.h)]{for p in ps{if !first{print!(",")}first=false;print!("{{\"cm\":\"{cm}\",\"parent\":{},\"domain\":\"{:?}\",\"part\":\"{:?}\",\"offset\":{},\"log\":{},\"rows\":{}}}",p.parent,p.domain,p.part,p.offset,p.log,p.rows_per_component);}}
  print!("],\"slots\":[");
  for (i,p) in s.slots.iter().enumerate(){if i>0{print!(",")}print!("{{\"base\":{},\"part\":\"{:?}\",\"main\":{},\"ext\":{},\"degree\":{},\"a_sites\":{},\"h_sites\":{},\"endpoint_sites\":{},\"a_pairs\":{:?},\"h_pairs\":{:?}}}",p.base,p.part,p.main,p.ext,p.degree,p.a_sites,p.h_sites,p.endpoint_sites,p.a_pairs,p.h_pairs);}
  println!("]}}");
 }}}
 eprintln!("extracted_constructor_and_audit_controls={controls}");
}
