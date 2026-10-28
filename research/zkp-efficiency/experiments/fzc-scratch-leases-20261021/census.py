"""Source-pinned constructor order and exhaustive synthetic reuse schedules."""
from pathlib import Path
import hashlib,itertools,json,resource,time

ROOT=Path(__file__).resolve().parent
start=time.monotonic(); checks=0
def check(b):
    global checks
    checks+=1
    assert b

pins=json.loads((ROOT/'source-pins.json').read_text())
for pin in pins:
    p=Path(pin['path']); check(hashlib.sha256(p.read_bytes()).hexdigest()==pin['sha256'])
native=next(Path(p['path']) for p in pins if p['path'].endswith('gpu-zerocheck/hashline/src/gpu/cuda.rs'))
t=native.read_text()
constructor=t[t.index('impl DevFzcRounds {'):t.index('/// the first device error',t.index('impl DevFzcRounds {'))]
check(constructor.index('let pin = PinBuf::new_read') < constructor.index('FzcMapped::new') < constructor.index('dev.synchronize().map_err(|e| format!("fzc build:'))
check('mapped, seq: 0' in constructor)
poll=t[t.index('let mut polled: Option<Vec<Fp2>>'):t.index('fn try_fold',t.index('let mut polled: Option<Vec<Fp2>>'))]
check(poll.index('self.mapped = None') < poll.index('cu::stream::synchronize(stream)'))
dep=Path('/home/victor/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/cudarc-0.13.9/src/driver/safe/alloc.rs')
dep_text=dep.read_text(); sync=dep_text[dep_text.index('pub fn synchronize(self: &Arc<Self>)'):][:220]
check('result::stream::synchronize(self.stream)' in sync)
(ROOT/'source/cudarc-0.13.9-alloc.rs').write_text(dep_text)
dp={'path':str(dep),'copy':str(ROOT/'source/cudarc-0.13.9-alloc.rs'),'sha256':hashlib.sha256(dep.read_bytes()).hexdigest()}
if not any(x['path']==str(dep) for x in pins):
    pins.append(dp); (ROOT/'source-pins.json').write_text(json.dumps(pins,indent=2)+'\n')

# W=old producer, S=successful ctor stream sync, Z=clear active range,
# L=new launch, N=new producer, P=one host poll. Message payloads are distinct.
# No native memory-model claim: this assumes system-fenced publication.
schedules=[]
for old_degree,new_degree,clear_after_sync,same_stream in itertools.product([4,5],[4,5],[False,True],[False,True]):
    nvalid=nunsafe=0
    for order in itertools.permutations('WSZLNP'):
        pos={c:order.index(c) for c in order}
        edges=[('S','L'),('Z','L'),('L','N'),('L','P')]
        edges += [('S','Z')] if clear_after_sync else [('Z','S')]
        if same_stream: edges.append(('W','S'))
        if any(pos[a]>=pos[b] for a,b in edges): continue
        memory=[1]*13; old_payload=tuple([1]* (2*(old_degree+1)))
        fresh=tuple([99+i for i in range(2*(new_degree+1))])
        observed=None
        for event in order:
            if event=='W':
                memory[:len(old_payload)]=old_payload
                memory[len(old_payload)]=1
            elif event=='Z': memory[:2*(new_degree+1)+1]=[0]*(2*(new_degree+1)+1)
            elif event=='N':
                memory[:len(fresh)]=fresh; memory[len(fresh)]=1
            elif event=='P':
                if memory[len(fresh)]==1: observed=tuple(memory[:len(fresh)])
        expected=fresh if pos['N']<pos['P'] else None
        unsafe=observed!=expected
        nunsafe+=unsafe; nvalid+=1
        if same_stream and clear_after_sync: check(not unsafe)
    schedules.append({'old_degree':old_degree,'new_degree':new_degree,'clear_after_sync':clear_after_sync,'same_stream':same_stream,'valid_interleavings':nvalid,'stale_or_wrong_observations':nunsafe})
safe=[x for x in schedules if x['same_stream'] and x['clear_after_sync']]
check(all(x['stale_or_wrong_observations']==0 for x in safe))
check(any(x['stale_or_wrong_observations']>0 for x in schedules if not x['clear_after_sync']))
check(all(x['stale_or_wrong_observations']>0 for x in schedules if not x['same_stream']))
result={'status':'PASS_SOURCE_AND_INTERLEAVING_MODEL_ONLY','checks':checks,'source_pin_count':len(pins),'schedule_families':schedules,'total_interleavings':sum(x['valid_interleavings'] for x in schedules),'safe_same_stream_post_sync_interleavings':sum(x['valid_interleavings'] for x in safe),'same_stream_post_sync_failures':sum(x['stale_or_wrong_observations'] for x in safe),'wall_seconds':time.monotonic()-start,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'scope':'Logical publication and stream-order assumptions only. No real driver, atomics, event, timeout, kernel or proof ran. Existing timeout drops mapping before explicit sync: review risk, not confirmed native use-after-free.'}
(ROOT/'census-result.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result))
