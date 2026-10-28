"""Separate source-order/role audit; imports no accounting implementation."""
import hashlib,json,resource,time
from pathlib import Path
ROOT=Path(__file__).resolve().parent
start=time.monotonic();checks=0
def check(x):
    global checks
    assert x
    checks+=1
pins=json.loads((ROOT/'source-pins.json').read_text())
for p in pins:
    check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
    check(hashlib.sha256((ROOT/'source'/Path(p['path']).name).read_bytes()).hexdigest()==p['sha256'])
c=(ROOT/'source/cuda.rs').read_text();f=(ROOT/'source/fzc.rs').read_text()
def part(text,a,b):
    x=text.index(a);y=text.index(b,x+len(a));return text[x:y]
ctor=part(c,'    pub fn new(srcs:', '    /// the first device error')
report=part(c,'    pub fn report(&mut self)', '    fn sync_if_prof')
sync=part(c,'    fn sync_if_prof', '    /// K4: one round')
fold=part(c,'    fn try_fold(&mut self', '\n/// the split kernel\'s warps')
tail=part(fold,'        if to_host {','        if last {')
mapped=part(c,'impl FzcMapped {','\nimpl Drop for FzcMapped')
pin=part(c,'    fn new_read(dev:', '\n    #[inline]')
prove=part(f,'pub fn prove(', '\n    #[cfg(not(feature = "gpu-cuda"))]')
check(ctor.index('let g = gpu()')<ctor.index('let g = g.lock()')<ctor.index('let warm_ms:')<ctor.index('let t0 = Instant::now()'))
check(ctor.index('let t0 = Instant::now()')<ctor.index('let module = fzc_module')<ctor.index('let pin = PinBuf::new_read')<ctor.index('let mapped = if split'))
check(ctor.index('let mapped = if split')<ctor.index('dev.synchronize().map_err(|e| format!("fzc build:')<ctor.index('st.secs_build = t0.elapsed()'))
check('self.st.secs_total = self.t0.elapsed()' in report)
check('if self.prof {' in sync and 'self.dev.synchronize()' in sync)
check(prove.index('let mut ev =')<prove.index('masked_prove_rounds')<prove.index('if let Some(e) = ev.error()')<prove.index('ev.report()')<prove.index('*tr = tr2')<prove.index('Ok(out)'))
check('drop(ev)' not in prove and 'impl Drop for DevFzcRounds' not in c)
check('return Err(e);' in prove[:prove.index('ev.report()')])
check(tail.index('let mut d_pack =')<tail.index('let mut pin =')<tail.index('cu::memcpy_dtoh_async')<tail.index('cu::stream::synchronize')<tail.index('self.st.secs_tail +='))
check('drop(pin)' not in tail and 'drop(d_pack)' not in tail)
check('cu::malloc_host(len.max(1) * 8, 0)' in pin)
check(mapped.index('cu::malloc_host')<mapped.index('cuMemHostGetDevicePointer_v2')<mapped.index('std::ptr::write_volatile'))
check('nv * 2 + 1' in ctor and 'nv * 2' in ctor and 'let nv = degree + 1;' in ctor)
check('let n_words = self.k * half * 2;' in tail)
check('let _ = cu::free_host' in part(c,'impl Drop for PinBuf','\n/// Fill a staging'))
check('let _ = cu::free_host' in part(c,'impl Drop for FzcMapped','\n/// `HL_GZC_FUSED'))
roles=[]
for degree in [4,5]:
    for k in [20,21]:
        for half in [2,16,32]:
            nv=degree+1
            row={'degree':degree,'k':k,'half':half,'fallback_pin_bytes':16*nv,
                 'mapped_pin_bytes':16*nv+8,'tail_pin_bytes':16*k*half,
                 'tail_device_pack_bytes':16*k*half,
                 'host_allocations_if_mapping_and_tail_reached':3,
                 'mapping_queries_if_mapping_reached':1}
            check(row['mapped_pin_bytes']-row['fallback_pin_bytes']==8)
            check(row['tail_pin_bytes']==row['tail_device_pack_bytes'])
            roles.append(row)
check(next(x for x in roles if (x['degree'],x['k'],x['half'])==(5,21,32))['tail_pin_bytes']==10752)
hooks=[]
anchors=[('cuda.rs','    pub fn new(srcs:','attempt/constructor: enter before gpu init and lock'),
 ('cuda.rs','        let t0 = Instant::now();','legacy build starts after optional warmup; locate in constructor'),
 ('cuda.rs','        let pin = PinBuf::new_read(&dev, nv * 2)?;','round fallback allocation role'),
 ('cuda.rs','            match FzcMapped::new(&dev, nv * 2 + 1) {','round mapped allocation/map/zero roles'),
 ('cuda.rs','    fn try_round(&mut self','round wrapper includes lock, launch and poll/copy'),
 ('cuda.rs','            let n_words = self.k * half * 2;','tail entry and pack/pin role sizes'),
 ('cuda.rs','            self.st.secs_tail += ta.elapsed().as_secs_f64();','tail clock sampled before local scope drop'),
 ('cuda.rs','    pub fn report(&mut self)','legacy total sampled before owner drop'),
 ('cuda.rs','impl Drop for PinBuf','exact host free API scope'),
 ('cuda.rs','impl Drop for FzcMapped','exact mapped host free API scope'),
 ('fzc.rs','        let mut ev = super::cuda::DevFzcRounds::new','caller attempt wrapper must enclose constructor and evaluator drop'),
 ('fzc.rs','        ev.report();','success-only report; failure exit needs separate accounting')]
for name,needle,note in anchors:
    text=(ROOT/'source'/name).read_text();lines=[i for i,l in enumerate(text.splitlines(),1) if needle in l];check(bool(lines))
    hooks.append({'file':name,'anchor':needle,'matching_lines':lines,'proposal':note})
result=dict(status='PASS_SOURCE_ORDER_AND_ROLE_FORMULAS_ONLY',checks=checks,source_pins=len(pins),
 source_findings=['constructor timer excludes prior GPU init/lock/memory diagnosis/optional warmup',
 'build timer combines allocation, transfer, module work and synchronize',
 'success-only total sampled before report overhead, transcript assignment and evaluator destruction',
 'tail sample precedes local pin and d_pack scope destruction',
 'profile-only round synchronization changes timing boundaries',
 'constructor and round errors can return without ev.report; enclosing caller attempt timer must survive early returns'],
 role_fixtures=roles,hooks=hooks,wall_seconds=time.monotonic()-start,
 rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 caveat='Source order and conditional request formulas only. Rust drop/API timing, driver fences, actual incidence and performance not executed.')
(ROOT/'source-audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['hooks','role_fixtures']},indent=2))
