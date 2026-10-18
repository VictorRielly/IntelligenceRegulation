"""Executed Fp2 API counters; instrumented CPU code is never timed as a speed test."""
from pathlib import Path
import ctypes as C,datetime,hashlib,json,os,resource,signal,subprocess,time
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();s=(H/'field-only.rs').read_text();at=s.index('impl Fp2 {')
prefix=s[:at];tail=s[at:]
counter='''
use std::sync::atomic::{AtomicUsize,Ordering};
static OPS:[AtomicUsize;3]=[AtomicUsize::new(0),AtomicUsize::new(0),AtomicUsize::new(0)];
#[no_mangle] pub extern "C" fn op_reset(){for x in &OPS{x.store(0,Ordering::Relaxed);}}
#[no_mangle] pub unsafe extern "C" fn op_read(out:*mut usize){for(j,x)in OPS.iter().enumerate(){*out.add(j)=x.load(Ordering::Relaxed);}}
'''
for j,name in enumerate(['add','sub','mul']):
 old=f'pub fn {name}(self, r: Fp2) -> Fp2 {{';assert tail.count(old)==1
 tail=tail.replace(old,old+f' OPS[{j}].fetch_add(1,Ordering::Relaxed);')
(H/'counted.rs').write_text(prefix+counter+tail+''.join((H/n).read_text()for n in ['ragged.rs','factorized.rs','pending.rs']))
argv=['/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc','--edition=2021','--crate-type=cdylib','-C','opt-level=1','-C','codegen-units=1','counted.rs','-o','counted.so']
with(H/'counted-compile.log').open('w')as log:subprocess.run(argv,cwd=H,env=dict(os.environ,TMPDIR=str(H/'tmp')),stdout=log,stderr=subprocess.STDOUT,check=True,timeout=25)
lib=C.CDLL(str(H/'counted.so'));U=C.c_uint64;S=C.c_size_t
for name in ['pending','factorized']:getattr(lib,name).argtypes=[S,S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),C.POINTER(S)]
lib.op_read.argtypes=[C.POINTER(S)]
def array(v):return(U*(2*len(v)))(*(x for a in v for x in a))
rows=[]
for f in json.loads((H/'fixtures.json').read_text()):
 n=f['rows'];c=f['columns'];r=f['challenges'];v=f['values'];ps=[x for p in f['initial_points']for x in p];cp=f['column_point'];arms={}
 for name in ['factorized','pending']:
  out=(U*(2*(4*len(r)+3)))();traffic=(S*4)();ops=(S*3)();lib.op_reset()
  rc=getattr(lib,name)(n,c,array(v),len(v),array(ps),len(ps),array(cp),len(cp),array(r),len(r),out,traffic)
  lib.op_read(ops);assert rc==0
  flat=[x for msg in f['rounds']for x in msg]+f['finals'];assert list(out)==[x for y in flat for x in y]
  arms[name]=list(ops)
 delta=[b-a for a,b in zip(arms['factorized'],arms['pending'])];w=1<<(c-1).bit_length()
 assert delta==[0,3*(w-1),0],(f['tag'],arms,delta)
 rows.append(dict(tag=f['tag'],rows=n,columns=c,operations_add_sub_mul=arms,delta_add_sub_mul=delta))
out=dict(status='PASS',fixtures=len(rows),delta_rule='0 Fp2 add, +3*(W-1) Fp2 sub, 0 Fp2 mul. Column-tail differences recomputed by split measure/bind; all row arithmetic counts unchanged.',instrumentation='Atomic counters inserted in exactly the three Fp2 API entry points add/sub/mul, not a physical instruction/DRAM model.',rows=rows,wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,compiler_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,compiler_argv=argv,threads=1,counted_source_sha256=hashlib.sha256((H/'counted.rs').read_bytes()).hexdigest(),completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'operations.json').write_text(json.dumps(out,indent=2)+'\n');small={k:v for k,v in out.items()if k!='rows'}
(H/'operations.log').write_text(json.dumps(small,indent=2)+'\n');print(json.dumps(small,indent=2))
