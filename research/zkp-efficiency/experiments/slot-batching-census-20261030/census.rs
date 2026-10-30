#![allow(dead_code)]
include!("native_metadata.rs");
use std::io::{self, Read};
fn main() {
 let text=std::fs::read_to_string("edges.tsv").unwrap();
 let edges:Vec<(usize,usize)>=text.lines().map(|l|{let v:Vec<_>=l.split_whitespace().collect();(v[0].parse().unwrap(),v[1].parse().unwrap())}).collect();
 let mut input=String::new();io::stdin().read_to_string(&mut input).unwrap();
 for line in input.lines() {
  let p:Vec<_>=line.split_whitespace().collect();assert_eq!(p.len(),11);
  let v:Vec<usize>=p[1..].iter().map(|s|s.parse().unwrap()).collect();
  let sh=Shape{tokens:v[0],width:v[1],hidden:v[2],q_heads:v[3],head_dim:v[4],kv_heads:v[5],log_cols:v[6],dd_cap:v[7],frozen:v[8]!=0,
    t_pad:v[0].next_power_of_two(),d_pad:v[1].next_power_of_two(),h_pad:v[3].next_power_of_two(),f_pad:v[2].next_power_of_two()};
  let n=sh.n_slots();let slots=sh.slots();let mut reach=[[false;24];24];
  for &(a,b) in &edges {assert!(a<b && b<n);reach[a][b]=true;}
  if v[9]!=0 {for a in 0..n-1 {reach[a][a+1]=true;}}
  for k in 0..n {for i in 0..n {for j in 0..n {reach[i][j]|=reach[i][k]&&reach[k][j];}}}
  let mut equal=0;let mut blocked=0;let mut independent=Vec::new();
  for i in 0..n {for j in i+1..n {if slots[i]==slots[j] {equal+=1;if reach[i][j]||reach[j][i] {blocked+=1;} else {independent.push((i,j));}}}}
  println!("{}|{:?}|{}|{}|{:?}",p[0],&slots[..n],equal,blocked,independent);
 }
}
