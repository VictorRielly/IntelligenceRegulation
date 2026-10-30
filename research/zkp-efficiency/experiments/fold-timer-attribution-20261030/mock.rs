#![allow(dead_code,private_interfaces)]
// Synthetic deterministic clock/device binding. This does not invoke CUDA.
use std::{cell::RefCell, io::Write, ops::Deref};
const P:u64=0xffff_ffff_0000_0001;
#[derive(Clone,Copy,Debug,PartialEq)] struct Fp(u64);
#[derive(Clone,Copy,Debug,PartialEq)] struct Fp2{c0:Fp,c1:Fp}
impl Fp2{fn new(c0:Fp,c1:Fp)->Self{charge(15);Self{c0,c1}}}
#[derive(Default)] struct Stats{secs_fold:f64,bytes_d2h:u64}
#[derive(Default)] struct State{t:u64,ready:u64,c:[u64;19],fail:usize,start:Option<u64>,sample:Option<u64>,stats:Stats,samples:u64,scope_end:u64}
thread_local!{static S:RefCell<State>=RefCell::new(State::default());}
fn charge(i:usize){S.with(|s|{let mut s=s.borrow_mut();s.t+=s.c[i];});}
fn fails(i:usize)->bool{S.with(|s|s.borrow().fail==i)}
fn queue(i:usize,wait:bool){S.with(|s|{let mut s=s.borrow_mut();s.ready=s.ready.max(s.t)+s.c[i];if wait{s.t=s.ready;}});}
struct Instant(u64);struct Duration(u64);
impl Instant{fn now()->Self{S.with(|s|{let mut s=s.borrow_mut();let t=s.t;s.start=Some(t);Self(t)})}fn elapsed(&self)->Duration{S.with(|s|{let mut s=s.borrow_mut();s.sample=Some(s.t);Duration(s.t-self.0)})}}
impl Duration{fn as_secs_f64(&self)->f64{self.0 as f64}} // ticks, deliberately not physical seconds
struct Scope;impl Drop for Scope{fn drop(&mut self){S.with(|s|{let mut s=s.borrow_mut();s.scope_end=s.t;});}}
struct Device;
impl Clone for Device{fn clone(&self)->Self{charge(2);Self}}
struct Gate{dev:Device}static G:Gate=Gate{dev:Device};
struct Guard;
impl Deref for Guard{type Target=Gate;fn deref(&self)->&Gate{&G}}
impl Drop for Guard{fn drop(&mut self){charge(18);}}
impl Gate{fn lock(&self)->Result<Guard,&'static str>{charge(1);if fails(2){Err("synthetic poisoned mutex")}else{Ok(Guard)}}}
fn gpu()->Option<&'static Gate>{charge(0);if fails(1){None}else{Some(&G)}}
fn init_err()->String{"synthetic init error".into()}
// Move Stats out of the fake clock cell so native callback elapsed() can read it.
fn stats_with<F:FnOnce(&mut Stats)>(f:F){charge(13);if fails(9){panic!("synthetic poisoned stats")};let mut st=S.with(|s|std::mem::take(&mut s.borrow_mut().stats));f(&mut st);S.with(|s|{let mut s=s.borrow_mut();s.stats=st;s.samples+=1;});charge(14);}
struct Data(Vec<u64>);impl Data{fn get(&self)->&Vec<u64>{&self.0}}
pub struct DevCommit{rows:usize,log_n:u32,data:Data}
struct Slice<T>{buf:Vec<T>,kind:usize}
impl<T> Drop for Slice<T>{fn drop(&mut self){charge(if self.kind==0{16}else{17});}}
struct LaunchConfig;impl LaunchConfig{fn for_num_elems(_:u32)->Self{Self}}
struct Function;
const MODULE:&str="synthetic";
impl Device{
 fn htod_sync_copy(&self,v:&[u64])->Result<Slice<u64>,String>{charge(4);if fails(3){return Err("rho alloc".into())};let d=Slice{buf:v.to_vec(),kind:0};charge(5);queue(6,true);if fails(4){return Err("h2d".into())};Ok(d)}
 unsafe fn alloc<T:Default+Clone>(&self,n:usize)->Result<Slice<T>,String>{charge(7);if fails(5){return Err("out alloc".into())};Ok(Slice{buf:vec![T::default();n],kind:1})}
 fn get_func(&self,_:&str,_:&str)->Option<Function>{charge(8);if fails(6){None}else{Some(Function)}}
 fn dtoh_sync_copy(&self,v:&Slice<u64>)->Result<Vec<u64>,String>{charge(11);queue(12,true);if fails(8){Err("d2h".into())}else{Ok(v.buf.clone())}}
}
impl Function{unsafe fn launch(&self,_:LaunchConfig,args:(&Vec<u64>,&Slice<u64>,&mut Slice<u64>,i32,i32,i32))->Result<(),String>{charge(9);if fails(7){return Err("launch".into())};let(data,rho,out,rows,n,k)=args;for g in 0..k as usize{for j in 0..n as usize{for limb in 0..2{let mut a=0u128;for i in 0..rows as usize{a=(a+(data[i*n as usize+j] as u128*rho.buf[2*(g*rows as usize+i)+limb] as u128))%(P as u128);}out.buf[2*(g*n as usize+j)+limb]=a as u64;}}}queue(10,false);Ok(())}}
include!("native_pack.rs");
fn as_u64s_f2(v:&[Fp2])->Vec<u64>{charge(3);as_u64s_f2_unclocked(v)}
// This function body is byte-for-byte extracted; all surrounding types are mocks.
include!("native_fold.rs");
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn main(){
 std::panic::set_hook(Box::new(|_|{}));
 let mut rng=202610300741u64;let mut f=std::fs::File::create("fixtures.jsonl").unwrap();let mut count=0;
 for case in 0..326{let (rows,n,k)=if case>=320{(1,8,4)}else{([0,1,3,7][case%4],1usize<<(case%4),1+(case/4)%4)};
  let mut c=[0u64;19];for x in &mut c{*x=next(&mut rng)%9;}let mut prior=next(&mut rng)%160;
  let mut fail=if case<80{0}else{(case/8)%10};
  if case>=320{c=[0;19];c[3]=if case==320||case==322{10}else{2};c[6]=2;c[10]=5;c[12]=2;prior=if case<=321{100}else{0};fail=0;if case==324{c[1]=30;}if case==325{c[15]=3;}}
  let data=(0..rows*n).map(|_|next(&mut rng)%P).collect::<Vec<_>>();
  let mut rhos=(0..k).map(|_|(0..rows).map(|_|Fp2{c0:Fp(next(&mut rng)%P),c1:Fp(next(&mut rng)%P)}).collect::<Vec<_>>()).collect::<Vec<_>>();
  let malformed=if (300..320).contains(&case){1+case%3}else{0};
  if malformed==1{rhos.clear();}else if malformed==2{rhos.push(vec![Fp2{c0:Fp(1),c1:Fp(2)};rows]);if rhos.len()<=4{while rhos.len()<5{rhos.push(vec![]);}}}else if malformed==3{rhos[0].push(Fp2{c0:Fp(1),c1:Fp(2)});}
  let input=rhos.iter().map(|v|v.iter().flat_map(|x|[x.c0.0,x.c1.0]).collect::<Vec<_>>()).collect::<Vec<_>>();
  S.with(|s|*s.borrow_mut()=State{c,fail,ready:prior,..State::default()});let dc=DevCommit{rows,log_n:n.trailing_zeros(),data:Data(data.clone())};
  let result=std::panic::catch_unwind(std::panic::AssertUnwindSafe(||{let _scope=Scope;dev_fold_rows(&dc,&rhos)}));
  let(outcome,out)=match result{Ok(Ok(v))=>("ok",v.iter().flat_map(|v|v.iter().flat_map(|x|[x.c0.0,x.c1.0])).collect::<Vec<_>>()),Ok(Err(_))=>("err",vec![]),Err(_)=>("panic",vec![])};
  S.with(|s|{let s=s.borrow();writeln!(f,"{{\"id\":{case},\"rows\":{rows},\"n\":{n},\"k\":{},\"costs\":{c:?},\"prior_ready\":{prior},\"fail\":{fail},\"malformed\":{malformed},\"data\":{data:?},\"rho\":{input:?},\"outcome\":\"{outcome}\",\"out\":{out:?},\"start\":{},\"sample\":{},\"counter_ticks\":{},\"samples\":{},\"bytes_d2h\":{},\"scope_end\":{},\"ready\":{}}}",rhos.len(),s.start.map(|x|x.to_string()).unwrap_or("null".into()),s.sample.map(|x|x.to_string()).unwrap_or("null".into()),s.stats.secs_fold,s.samples,s.stats.bytes_d2h,s.scope_end,s.ready).unwrap();});count+=1;
 }
 println!("{{\"status\":\"PASS\",\"fixtures\":{count},\"full_stack_proofs\":0,\"positions\":0}}");
}
