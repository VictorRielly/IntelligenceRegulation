// Authored local probe. Original Vec decode API; scalar analogue of native
// pad_matrix. Tracks requested System allocations, not malloc usable size/RSS.
// No custom decoded Drop, black_box, dependency, Rayon or production prover.
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering::Relaxed};
use std::io::Write;

struct TrackedSystem;
static ACTIVE: AtomicBool = AtomicBool::new(false);
static PHASE: AtomicUsize = AtomicUsize::new(0);
static USED: AtomicUsize = AtomicUsize::new(0);
static OVERFLOW: AtomicBool = AtomicBool::new(false);
// Fixed static log: allocator hooks only use atomics, never allocate or panic.
static LOG: [AtomicUsize; 4096] = [const { AtomicUsize::new(0) }; 4096];
fn event(kind: usize, ptr: usize, bytes: usize) {
    if !ACTIVE.load(Relaxed) { return; }
    let n = USED.fetch_add(4, Relaxed);
    if n + 3 >= LOG.len() { OVERFLOW.store(true, Relaxed); return; }
    LOG[n].store(kind, Relaxed);
    LOG[n+1].store(ptr, Relaxed);
    LOG[n+2].store(bytes, Relaxed);
    LOG[n+3].store(PHASE.load(Relaxed), Relaxed);
}
// SAFETY: forward every allocation with its unchanged Layout to System;
// no inspection of user memory, no allocation/logging recursion or unwind.
unsafe impl GlobalAlloc for TrackedSystem {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let p = unsafe { System.alloc(layout) };
        if !p.is_null() { event(1, p as usize, layout.size()); }
        p
    }
    unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8 {
        let p = unsafe { System.alloc_zeroed(layout) };
        if !p.is_null() { event(1, p as usize, layout.size()); }
        p
    }
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        event(2, ptr as usize, layout.size());
        unsafe { System.dealloc(ptr, layout) };
    }
    unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, size: usize) -> *mut u8 {
        let p = unsafe { System.realloc(ptr, layout, size) };
        if !p.is_null() {
            event(2, ptr as usize, layout.size());
            event(1, p as usize, size);
            event(4, 0, size); // explicitly visible realloc control
        }
        p
    }
}
#[global_allocator]
static ALLOCATOR: TrackedSystem = TrackedSystem;

struct Array { bytes: Vec<u8> }
impl Array {
    // Byte-for-byte original native body/API, without a custom Drop wrapper.
    fn i8s(&self) -> Vec<i8> {
        self.bytes.iter().map(|b| *b as i8).collect()
    }
}
struct Spec { to: usize, ti: usize, po: usize, pi: usize, omap: Vec<usize>, imap: Vec<usize> }
fn phase(i: usize, class: usize) { PHASE.store(10 * (i + 1) + class, Relaxed); }
fn decode(a: &Array, i: usize) -> Vec<i8> { phase(i, 1); a.i8s() }

fn pad_matrix(w: &[i8], s: &Spec, i: usize) -> Vec<i8> {
    event(3, 0, i); // checkpoint at entry, before output/map allocations
    let (to, ti, po, pi) = (s.to, s.ti, s.po, s.pi);
    phase(i, 2);
    let mut out = vec![0i8; po * pi];
    phase(i, 3);
    let mut src_of: Vec<Option<usize>> = vec![None; po];
    for o in 0..to { src_of[s.omap[o]] = Some(o); }
    phase(i, 4);
    let inner: Vec<usize> = (0..ti).map(|j| s.imap[j]).collect();
    let identity = inner.iter().enumerate().all(|(i, j)| i == *j);
    // This is the native destination-row implementation with par_chunks_mut
    // replaced by chunks_mut. No threadpool or Rayon behavior is measured.
    out.chunks_mut(pi).enumerate().for_each(|(r, row)| {
        let Some(o) = src_of[r] else { return };
        let src = &w[o * ti..(o + 1) * ti];
        if identity { row[..ti].copy_from_slice(src); }
        else { for (j, v) in src.iter().enumerate() { row[inner[j]] = *v; } }
    });
    out
}
fn direct(a: &Array, s: &Spec, i: usize) -> Vec<i8> {
    // Separate control: no decode allocation; destination and map allocations
    // remain. Direct per-byte implementation is not a native speed benchmark.
    event(3, 0, i);
    phase(i, 2); let mut out = vec![0i8; s.po * s.pi];
    phase(i, 3); let mut src_of: Vec<Option<usize>> = vec![None; s.po];
    for o in 0..s.to { src_of[s.omap[o]] = Some(o); }
    phase(i, 4); let inner: Vec<usize> = (0..s.ti).map(|j| s.imap[j]).collect();
    for (r, row) in out.chunks_mut(s.pi).enumerate() {
        if let Some(o) = src_of[r] {
            for j in 0..s.ti { row[inner[j]] = a.bytes[o*s.ti+j] as i8; }
        }
    }
    out
}
type Outputs = ([Vec<i8>; 5], [Vec<i8>; 4]);
fn run(mode: usize, a: &[Array;9], s: &[Spec;9]) -> Outputs {
    let aw; let fw;
    match mode {
        0 => {
            aw = [pad_matrix(&decode(&a[0],0),&s[0],0),pad_matrix(&decode(&a[1],1),&s[1],1),
                  pad_matrix(&decode(&a[2],2),&s[2],2),pad_matrix(&decode(&a[3],3),&s[3],3),
                  pad_matrix(&decode(&a[4],4),&s[4],4)];
            fw = [pad_matrix(&decode(&a[5],5),&s[5],5),pad_matrix(&decode(&a[6],6),&s[6],6),
                  pad_matrix(&decode(&a[7],7),&s[7],7),pad_matrix(&decode(&a[8],8),&s[8],8)];
        }
        1 | 4 => {
            let a0=pad_matrix(&decode(&a[0],0),&s[0],0);
            let a1=pad_matrix(&decode(&a[1],1),&s[1],1);
            let a2=pad_matrix(&decode(&a[2],2),&s[2],2);
            let a3=pad_matrix(&decode(&a[3],3),&s[3],3);
            let a4=pad_matrix(&decode(&a[4],4),&s[4],4);
            aw=[a0,a1,a2,a3,a4];
            let f0=pad_matrix(&decode(&a[5],5),&s[5],5);
            let f1=pad_matrix(&decode(&a[6],6),&s[6],6);
            let f2=pad_matrix(&decode(&a[7],7),&s[7],7);
            let f3=pad_matrix(&decode(&a[8],8),&s[8],8);
            fw=[f0,f1,f2,f3];
            if mode==4 {
                // Negative: same values but nine avoidable output clones.
                let ac=std::array::from_fn(|i| {phase(i,5); aw[i].clone()});
                let fc=std::array::from_fn(|i| {phase(i+5,5); fw[i].clone()});
                return (ac,fc);
            }
        }
        2 => {
            let a0=&decode(&a[0],0);let a1=&decode(&a[1],1);let a2=&decode(&a[2],2);
            let a3=&decode(&a[3],3);let a4=&decode(&a[4],4);
            aw=[pad_matrix(a0,&s[0],0),pad_matrix(a1,&s[1],1),pad_matrix(a2,&s[2],2),
                pad_matrix(a3,&s[3],3),pad_matrix(a4,&s[4],4)];
            let f0=&decode(&a[5],5);let f1=&decode(&a[6],6);
            let f2=&decode(&a[7],7);let f3=&decode(&a[8],8);
            fw=[pad_matrix(f0,&s[5],5),pad_matrix(f1,&s[6],6),
                pad_matrix(f2,&s[7],7),pad_matrix(f3,&s[8],8)];
        }
        3 => {
            aw=std::array::from_fn(|i|direct(&a[i],&s[i],i));
            fw=std::array::from_fn(|j|direct(&a[j+5],&s[j+5],j+5));
        }
        _ => unreachable!()
    }
    (aw,fw)
}
fn main() {
    // Arguments originate from authored fixture generator, parsed outside region.
    let args: Vec<String> = std::env::args().collect();
    let output_dir = &args[1];
    let seed: usize = args[2].parse().unwrap();
    let cases: [(usize,usize,usize,usize,Vec<usize>);8]=[(4,1,4,25,vec![0,1,2,3]),(3,2,4,13,vec![0,2,3]),
               (3,1,4,29,vec![3,0,2]),(2,1,8,17,vec![1,0]),
               (1,1,4,7,vec![0]),(5,2,2,11,vec![6,0,3,1,5]),
               (4,2,16,97,vec![2,0,3,1]),(32,8,4,448,(0..32).collect())];
    let thread_status=std::fs::read_to_string("/proc/self/status").unwrap();
    let threads=thread_status.lines().find(|l|l.starts_with("Threads:")).unwrap().split_whitespace().nth(1).unwrap();
    for (case,(qh,kvh,hd,f,slots)) in cases.iter().enumerate() {
        let d=qh*hd;let dp=(slots.iter().max().unwrap()+1)*hd;
        let dp=dp.next_power_of_two();let fp=(*f).next_power_of_two();let kv=kvh*hd;
        let q: Vec<usize>=(0..d).map(|j|slots[j/hd]*hd+j%hd).collect();
        let shape=[(d,d,dp,dp),(kv,d,kv,dp),(kv,d,kv,dp),(d,d,dp,dp),(1,d,1,dp),
                   (1,d,1,dp),(d,*f,dp,fp),(d,*f,dp,fp),(*f,d,fp,dp)];
        let specs: [Spec;9]=std::array::from_fn(|i|{
            let (to,ti,po,pi)=shape[i];
            Spec{to,ti,po,pi,omap:if i==0 {q.clone()} else {(0..to).collect()},
                 imap:if i==3 {q.clone()} else {(0..ti).collect()}}
        });
        let arrays: [Array;9]=std::array::from_fn(|i|Array{bytes:
            (0..shape[i].0*shape[i].1).map(|j|((seed+case*101+j*73+i*19)%256) as u8).collect()});
        for mode in 0..5 {
            USED.store(0,Relaxed);OVERFLOW.store(false,Relaxed);PHASE.store(0,Relaxed);
            ACTIVE.store(true,Relaxed);
            let result=run(mode,&arrays,&specs);
            ACTIVE.store(false,Relaxed);
            let count=USED.load(Relaxed);
            assert!(!OVERFLOW.load(Relaxed));
            let name=format!("case-{case}-mode-{mode}.bin");
            let mut file=std::fs::File::create(std::path::Path::new(output_dir).join(&name)).unwrap();
            for v in result.0.iter().chain(result.1.iter()) {
                let bytes: Vec<u8>=v.iter().map(|b|*b as u8).collect();
                file.write_all(&bytes).unwrap();
            }
            print!("{{\"case\":{case},\"mode\":{mode},\"seed\":{seed},\"qh\":{qh},\"kvh\":{kvh},\"hd\":{hd},\"f\":{f},\"d\":{d},\"dp\":{dp},\"fp\":{fp},\"slots\":{slots:?},\"threads\":{threads},\"usize_bytes\":{},\"option_usize_bytes\":{},\"output\":\"{name}\",\"events\":[",std::mem::size_of::<usize>(),std::mem::size_of::<Option<usize>>());
            for n in (0..count).step_by(4) {
                if n>0 {print!(",");}
                print!("[{},{},{},{}]",LOG[n].load(Relaxed),LOG[n+1].load(Relaxed),LOG[n+2].load(Relaxed),LOG[n+3].load(Relaxed));
            }
            println!("]}}");
        }
    }
}
