#![allow(dead_code)]
mod layout {
pub(crate) const SH_ROPE: u32 = 7;
pub(crate) const A_D: usize = 0;
pub(crate) const A_DSQ: usize = 1;
pub(crate) const A_DM: usize = 2;
pub(crate) const A_DSQM: usize = 3;
pub(crate) const A_MX: usize = 4;
pub(crate) const A_SUM: usize = 5;
pub(crate) const A_LIMB: usize = 6;
pub(crate) const A_LIMBM: usize = 7;
pub(crate) const A_X: usize = 8;
pub(crate) const A_XL0: usize = 9;
pub(crate) const A_XL1: usize = 10;
pub(crate) const A_Y: usize = 11;
pub(crate) const A_NR0: usize = 12;
pub(crate) const A_NS0: usize = 16;
pub(crate) const A_AO: usize = 20;
pub(crate) const A_AL0: usize = 21;
pub(crate) const A_AL1: usize = 22;
pub(crate) const A_RAL: usize = 23;
pub(crate) const A_X1: usize = 24;
pub(crate) const A_X1L0: usize = 25;
pub(crate) const A_X1L1: usize = 26;
pub(crate) const A_YM: usize = 27;
pub(crate) const A_MR0: usize = 28;
pub(crate) const A_MS0: usize = 32;
pub(crate) const A_Z16: usize = 36;
pub(crate) const A_X2: usize = 37;
pub(crate) const A_X2L0: usize = 38;
pub(crate) const A_X2L1: usize = 39;
pub(crate) const A_ZL0: usize = 40;
pub(crate) const A_ZL1: usize = 41;
pub(crate) const A_RDL: usize = 42;
pub(crate) const A_Q8: usize = 43;
pub(crate) const A_RQL: usize = 44;
pub(crate) const A_QR8: usize = 45;
pub(crate) const A_RQRL: usize = 46;
pub(crate) const A_O8: usize = 47;
pub(crate) const A_RO0: usize = 48;
pub(crate) const A_RO1: usize = 49;
pub(crate) const A_K8: usize = 50;
pub(crate) const A_RKL: usize = 51;
pub(crate) const A_V8: usize = 52;
pub(crate) const A_RVL: usize = 53;
pub(crate) const A_KR8: usize = 54;
pub(crate) const A_RKRL: usize = 55;
pub(crate) const A_S8: usize = 56;
pub(crate) const A_RSL: usize = 57;
pub(crate) const A_ZSEL: usize = 58;
pub(crate) const A_E: usize = 59;
pub(crate) const A_P: usize = 60;
pub(crate) const A_PL0: usize = 61;
pub(crate) const A_PL1: usize = 62;
pub(crate) const A_SR0: usize = 63;
pub(crate) const A_SR1: usize = 64;
pub(crate) const A_SG0: usize = 65;
pub(crate) const A_SG1: usize = 66;
pub(crate) const A_G8: usize = 67;
pub(crate) const A_RGL: usize = 68;
pub(crate) const A_A16: usize = 69;
pub(crate) const A_U16: usize = 70;
pub(crate) const A_UL0: usize = 71;
pub(crate) const A_UL1: usize = 72;
pub(crate) const A_H16: usize = 73;
pub(crate) const A_HL0: usize = 74;
pub(crate) const A_HL1: usize = 75;
pub(crate) const A_RH0: usize = 76;
pub(crate) const A_RH1: usize = 77;
pub(crate) const A_MU8: usize = 78;
pub(crate) const A_MEXP: usize = 79;
pub(crate) const A_MACT: usize = 80;
pub(crate) const N_A: usize = 81;
pub(crate) const LN_TOY: usize = 4;
pub(crate) const LS_TOY: usize = 2;
pub(crate) const LP_TOY: usize = 2;
pub(crate) const A_GROUPS: usize = 35;
pub(crate) const A_ROWS: usize = 455;
pub(crate) const A_DATA_ROWS: usize = 213;
#[derive(Clone,Copy,Debug,PartialEq,Eq)] pub enum Dom {T,Ht,L,D,Q,Kv,S,F,Tab,Dd}
pub struct Lk {pub terms:Vec<(usize,i64)>,pub cst:i64}
}
#[path="/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/frozen-tree/hashline/src/private_block/accuracy_precision.rs"] mod accuracy_precision;
#[path="/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/frozen-tree/hashline/src/private_block/accuracy_layout.rs"] mod accuracy_layout;
use accuracy_precision::{Stack,BaseShifts,derive};
use accuracy_layout::AccuracyIds;
use layout::Dom;
fn main() {
 for dd in [false,true] {for ls in [2,3] {
  let ids=AccuracyIds::new(Stack::LowH24,dd,ls).unwrap();
  let p=derive(Stack::LowH24,BaseShifts{norm_tn:9,qkv:8,score:6,pv:9,ao:7,gate:8,up:0,product:14,down:6}).unwrap();
  for (i,(dom,name)) in ids.doms.iter().zip(&ids.names).enumerate() {println!("ROLE,{dd},{ls},A,{dom:?},{i},{name}");}
  for dom in [Dom::T,Dom::Ht,Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F,Dom::Tab,Dom::Dd] {
   if dom==Dom::Dd && !dd {continue;}
   let n=ids.lookups(dom,&p,20,if ls==2 {16} else {24}).unwrap().len();
   println!("LOOKUPS,{dd},{ls},{dom:?},{n}");
  }
 }}
}
