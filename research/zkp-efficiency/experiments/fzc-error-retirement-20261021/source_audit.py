"""Separate source and combinatorial audit; imports neither candidate nor oracle."""
from pathlib import Path
import hashlib,itertools,json,math,resource,time
ROOT=Path(__file__).resolve().parent
t0=time.monotonic(); checks=0
def check(ok, msg):
    global checks
    checks+=1
    if not ok: raise AssertionError(msg)
pins=json.loads((ROOT/'source-pins.json').read_text())
for p in pins:
    copy=ROOT.parent.parent/p['copy']
    check(hashlib.sha256(copy.read_bytes()).hexdigest()==p['sha256'], 'snapshot pin')
    check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'], 'live source changed')
s=(ROOT/'source/cuda.rs').read_text(); k=(ROOT/'source/fzc_kernels.cu').read_text(); lib=(ROOT/'source/cudarc-0.13.9-alloc.rs').read_text()
round_start=s.index('let mut polled: Option<Vec<Fp2>> = None;')
drop=s.index('self.mapped = None;',round_start)
copy=s.index('cu::memcpy_dtoh_async',drop)
sync=s.index('cu::stream::synchronize(stream)',copy)
check(round_start < drop < copy < sync, 'mapped timeout drop/copy/sync order changed')
mapped_drop=s[s.index('impl Drop for FzcMapped'):s.index('/// `HL_GZC_FUSED')]
pin_drop=s[s.index('impl Drop for PinBuf'):s.index('/// Fill a staging buffer')]
for name,part in [('mapped',mapped_drop),('pin',pin_drop)]:
    check('cu::free_host' in part and 'synchronize' not in part, name+' destructor changed')
check('impl Drop for DevFzcRounds' not in s, 'custom owner Drop now needs review')
check('unsafe { result::stream::synchronize(self.stream) }' in lib, 'device sync scope changed')
pub=k.index('// [round 4] the mapped page-locked result:')
check(k.index('__threadfence_system();',pub) < k.index('((volatile u64*)mapped)[NV * 2] = seq;',pub), 'publication order changed')
check('let pin = PinBuf::new_read(&dev, nv * 2)?;' in s, 'eager fallback changed')

# A separate permutation filter replaces the recursive reference enumerator.
events=['publish','kernel_done','copy_done','a_sync','b_done','b_sync','cleanup']
counts={x:0 for x in ['timeout_drop','published_flag','a_sync_only']}; valid=0
for order in itertools.permutations(events):
    pos={v:i for i,v in enumerate(order)}
    if not (pos['publish']<pos['kernel_done']<pos['copy_done']<pos['a_sync'] and pos['b_done']<pos['b_sync']): continue
    valid+=1
    end=pos['cleanup']
    safe=all(pos[x]<end for x in ['kernel_done','copy_done','b_done'])
    if not safe:
        counts['timeout_drop']+=1
        counts['published_flag']+=pos['publish']<end
        counts['a_sync_only']+=pos['a_sync']<end
r=json.loads((ROOT/'result.json').read_text())
check(valid==math.factorial(7)//(math.factorial(4)*math.factorial(2))==r['topological_interleavings'], 'interleaving count')
check(counts==r['unsafe_control_schedules'], 'negative counts')
check(r['differential_cases']==48*sum(range(1,5))**2, 'exhaustive case count')
check(sum(r['decision_counts'].values())==r['differential_cases'], 'decision totals')

# Role-specific error path reference (all uses may remain outstanding on error).
# Return-code failures do not prove that a preceding launch/copy was cancelled.
paths=[]
for failure in ['none','bind_before_copy','copy_error','event_record_error','sync_error','context_poison']:
    for other_stream in [False,True]:
        for late_sync in ['none','a_success','a_and_b_success']:
            mapped={'kernel_a'}; fallback=set()
            if failure!='bind_before_copy': fallback.add('copy_a')
            if other_stream: mapped.add('reader_b')
            completed=set()
            if failure=='none' or late_sync in ['a_success','a_and_b_success']:
                completed|={'kernel_a','copy_a'}
            if late_sync=='a_and_b_success': completed.add('reader_b')
            poisoned=failure=='context_poison'
            safe_roles={name: (not poisoned and uses.issubset(completed)) for name,uses in [('mapped',mapped),('fallback',fallback)]}
            # Admission/proof outcome is independent of memory's cleanup state.
            proof_outcome='continue' if failure=='none' else 'refuse'
            paths.append({'failure':failure,'other_stream':other_stream,'late_sync':late_sync,'safe_roles':safe_roles,'attempt':proof_outcome})
            check(failure=='none' or proof_outcome=='refuse', 'error laundering')
            if poisoned: check(not any(safe_roles.values()), 'poison release')

out={'status':'PASS_SOURCE_AND_SEPARATE_REFERENCE_ONLY','checks':checks,'source_pins':len(pins),
     'interleavings':valid,'control_counts':counts,'role_error_paths':paths,
     'wall_seconds':time.monotonic()-t0,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
     'caveat':'Operation completion is a conservative last-use bound, not evidence of actual post-flag mapped accesses or a native use-after-free.'}
(ROOT/'source-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k!='role_error_paths'}))
