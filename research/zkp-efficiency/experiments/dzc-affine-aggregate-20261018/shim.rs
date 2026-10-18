#![allow(dead_code,non_upper_case_globals,unused_variables)]
// Exact u128 modular substitute, no native PTX/field implementation claimed.
const P:u128=18446744069414584321;
type Fp=u64;
static mut COUNTS:[u64;4]=[0;4];
#[repr(C)] #[derive(Clone,Copy)] struct Fp2{a:u64,b:u64}
fn plus(a:u64,b:u64)->u64{((a as u128+b as u128)%P) as u64}
fn minus(a:u64,b:u64)->u64{((a as u128+P-b as u128)%P) as u64}
fn times(a:u64,b:u64)->u64{((a as u128*b as u128)%P) as u64}
impl Fp2{
 const ZERO:Self=Self{a:0,b:0}; const ONE:Self=Self{a:1,b:0};
 fn add(self,o:Self)->Self{unsafe{COUNTS[0]+=1;} Self{a:plus(self.a,o.a),b:plus(self.b,o.b)}}
 fn sub(self,o:Self)->Self{unsafe{COUNTS[1]+=1;} Self{a:minus(self.a,o.a),b:minus(self.b,o.b)}}
 fn mul(self,o:Self)->Self{unsafe{COUNTS[2]+=1;} Self{a:plus(times(self.a,o.a),times(7,times(self.b,o.b))),b:plus(times(self.a,o.b),times(self.b,o.a))}}
 fn mul_base(self,o:u64)->Self{unsafe{COUNTS[3]+=1;} Self{a:times(self.a,o),b:times(self.b,o)}}
}
fn k(i:i64)->Fp2{Fp2{a:((i as i128).rem_euclid(P as i128)) as u64,b:0}}
include!("constants.rs.inc");
#[no_mangle]
pub unsafe extern "C" fn original(vp:*const u64,mp:*const u64,cp:*const u64,ln:usize,out:*mut u64,counts:*mut u64){
 let v=std::slice::from_raw_parts(vp as *const Fp2,64);
 let mu=std::slice::from_raw_parts(mp as *const Fp2,11);
 let c=std::slice::from_raw_parts(cp,8);
 let (b_num,b_num_m,b_dv,b_den,b_p1)=(c[0],c[1],c[2],c[3],256u64);
 let idx:Vec<usize>=(0..81).collect();let (ig,igm,id,idm)=(3usize,4usize,43usize,44usize);
 let ws=|i:usize,start:usize| -> Vec<(usize,Fp)>{(0..ln).map(|j|(if j<4{start+j}else{46+i*(ln-4)+j-4},(1u128<<(8*j)) as u64)).collect()};
 let (w_nr,w_ns,w_mr,w_ms)=(ws(0,12),ws(1,16),ws(2,28),ws(3,32));
 COUNTS=[0;4];
 let r:Fp2=include!("clauses-expression.rs.inc");
 *out=r.a;*out.add(1)=r.b;for i in 0..4{*counts.add(i)=COUNTS[i];}
}
