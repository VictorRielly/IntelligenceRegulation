import hashlib, json, pathlib, platform, os
D = pathlib.Path(__file__).resolve().parent
P = D.parents[3]
R = pathlib.Path('/home/victor/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/cudarc-0.13.9')
pins = []
for p in [P/'hashline/src/gpu/cuda.rs', P/'hashline/Cargo.toml', R/'src/driver/safe/alloc.rs', R/'src/driver/safe/core.rs', R/'Cargo.toml', R/'LICENSE-MIT']:
    b = p.read_bytes(); out = D/'native'/('cudarc' if R in p.parents else 'project')/p.relative_to(R if R in p.parents else P)
    out.parent.mkdir(parents=True, exist_ok=True); out.write_bytes(b)
    pins.append(dict(path=str(p), snapshot=str(out.relative_to(D)), sha256=hashlib.sha256(b).hexdigest()))
s = (P/'hashline/src/gpu/cuda.rs').read_text()
def extract(name):
    a=s.index(name); z=s.index('\n}', a)+2
    return s[a:z]
body=extract('pub fn dev_fold_rows(')
(D/'native_fold.rs').write_text(body+'\n')
helper=extract('fn as_u64s_f2(').replace('fn as_u64s_f2(', 'fn as_u64s_f2_unclocked(', 1)
(D/'native_pack.rs').write_text(helper+'\n')
obligations={
 'init_before_clock':body.index('let g = gpu()')<body.index('let t0 = Instant::now()'),
 'lock_before_clock':body.index('g.lock().unwrap()')<body.index('let t0 = Instant::now()'),
 'sample_before_conversion':body.index('stats_with(')<body.index('Ok((0..k)'),
 'sample_after_download':body.index('dtoh_sync_copy')<body.index('stats_with('),
 'error_before_counter':all(body.index(x)<body.index('stats_with(') for x in ['htod_sync_copy','dev.alloc','get_func','f.launch','dtoh_sync_copy']),
 'stats_lock_before_callback':'f(&mut STATS.lock().unwrap());' in s,
 'copy_wrapper_synchronizes':(R/'src/driver/safe/alloc.rs').read_text().count('self.synchronize()')>=2,
 'slice_drop_can_enqueue_free':'result::free_async(self.cu_device_ptr, self.device.stream)' in (R/'src/driver/safe/core.rs').read_text(),
}
assert all(obligations.values())
(D/'source-audit.json').write_text(json.dumps(dict(status='PASS', checks=obligations, exact_fold_body=True, helper_only_symbol_renamed=True),indent=2)+'\n')
(D/'source-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
cpu=next(x.split(':',1)[1].strip() for x in pathlib.Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))
(D/'hardware.json').write_text(json.dumps(dict(cpu=cpu, platform=platform.platform(), affinity=sorted(os.sched_getaffinity(0)), accelerator_used=False),indent=2)+'\n')
print(json.dumps(dict(status='PASS',source_pins=len(pins),source_checks=len(obligations))))
