"""Public source-backed event counts. No model arrays, device or native run."""
from pathlib import Path
import hashlib,json,resource,time
ROOT=Path(__file__).resolve().parent
checks=0
def ck(x):
    global checks
    assert x
    checks+=1

class Capacity:
    """Count physical selected-owner bytes, cache pins and external leases."""
    def __init__(self, cache):
        self.cache=cache;self.pins={};self.objs={};self.leases={}
        self.events=[];self.total=0;self.peak=0;self.builds=0;self.next_id=0
    def snap(self,kind):
        live=sum(self.objs.values());self.peak=max(self.peak,live)
        self.events.append(dict(kind=kind,bytes=live,pinned=len(self.pins),leases=len(self.leases)))
    def collect(self):
        refs=set(self.pins.values())|set(self.leases.values())
        self.objs={i:n for i,n in self.objs.items() if i in refs}
    def get(self,label,size,key=('goldilocks','canonical-u64',7,0,0)):
        old=self.pins.get(key)
        if self.cache and old is not None and self.objs[old]>=size:
            self.leases[label]=old;self.snap('hit:'+label);return
        obj=self.next_id;self.next_id+=1
        self.objs[obj]=size;self.builds+=1;self.total+=size
        self.leases[label]=obj
        # An actual grow allocates before replacing/freeing the old pin.
        self.snap('allocate:'+label)
        if self.cache:self.pins[key]=obj
        self.collect();self.snap('publish:'+label)
    def free(self,label):
        del self.leases[label];self.collect();self.snap('release:'+label)
    def evict(self):
        self.pins.clear();self.collect();self.snap('evict')

def trace(tokens,lc,layers,passes,cached,deferred,evict_per_pass=False):
    nn=4*(1<<lc);dev=Capacity(cached);host=Capacity(cached)
    requests=[]
    def get(label,size,device=True):
        host.get(label,size);host.free(label)
        requests.append(dict(role=label,words=size//8,device_offered=device))
        if device:dev.get(label,size)
        if device and not deferred:dev.free(label)
    def release(label):
        if deferred:dev.free(label)
    for r in range(passes):
        prefix='r'+str(r)+':'
        get(prefix+'E0',8*nn);get(prefix+'E1',8*nn)
        prev=None
        for k in range(layers):
            cur=prefix+'B'+str(k) if k+1<layers else None
            if cur:get(cur,8*nn)
            get(prefix+'A'+str(k),8*nn)
            get(prefix+'M'+str(k),8*4096,False)
            get(prefix+'H'+str(k),8*nn)
            release(prefix+'A'+str(k));release(prefix+'H'+str(k))
            release(prev if prev is not None else prefix+'E0')
            if k+1==layers:release(prefix+'E1')
            prev=cur
        ck(not dev.leases)
        if evict_per_pass:dev.evict();host.evict()
    main_count=sum(x['device_offered'] for x in requests)
    ck(main_count==passes*(3*layers+1))
    ck(len(requests)==passes*(4*layers+1))
    ck(sum(x['words'] for x in requests)==passes*((3*layers+1)*nn+layers*4096))
    # Private salt generation is untouched: one32B salt per encoded column.
    salt_bytes=sum(x['words']*32 for x in requests)
    return dict(tokens=tokens,lc=lc,layers=layers,passes=passes,cached=cached,
                deferred=deferred,evict_per_pass=evict_per_pass,
                public_requests=len(requests),device_offered_requests=main_count,
                cpu_public_words_built=host.total//8,device_powers_uploaded_B=dev.total,
                selected_host_peak_B=host.peak,selected_device_peak_B=dev.peak,
                selected_device_idle_B=sum(dev.objs.values()),
                host_builds=host.builds,device_uploads=dev.builds,
                private_salt_bytes_unchanged=salt_bytes,
                fresh_pad_words='sum(rows_of_each_commitment * q_pad), unchanged; not numerically censused',
                requests=requests,device_events=dev.events,host_events=host.events)

def run():
    start=time.monotonic();src=ROOT/'source'
    fragments=[
      ('r9__hashline__src__private_block__shape.rs','128 => Some(14)'),
      ('r9__hashline__src__private_block__shape.rs','32 => Some(LLAMA3_8B_LOG_COLS)'),
      ('r9__hashline__src__private_block__shape.rs','pub(crate) const LLAMA3_8B_LOG_COLS: usize = 13;'),
      ('r9__hashline__src__private_block__protocol.rs','let mut a = pcs::commit_zk_owned_tagged('),
      ('r9__hashline__src__private_block__protocol.rs','let mut h = pcs::commit_zk_owned_tagged('),
      ('r9__hashline__src__private_block__protocol.rs','let mc = zk::mask_commit_tagged('),
      ('r9__hashline__src__private_block__run.rs','if k + 1 < l {'),
      ('r9__hashline__src__private_block__run.rs','boundary::prepare(&spec,'),
      ('r9__hashline__src__private_block__run.rs','let ntt = NttTables::new(st.rs.ntt_log());'),
      ('r9__hashline__src__private_block__endpoint_g.rs','pcs::commit_zk_owned_tagged('),
      ('r9__hashline__src__private_block__boundary.rs','pcs::commit_zk_owned_tagged('),
      ('r9__hashline__src__zk.rs','let pows = coset_powers(Fp::new(7), dom);'),
      ('r9__zkp-core__src__pcs.rs','let pows = coset_powers(zk.coset, nn);'),
      ('r9__zkp-core__src__pcs.rs','assert!(x != Fp::ONE,'),
      ('r9__zkp-core__src__pcs.rs','let pads = rng.fp_vec(rows * q);'),
      ('r9__zkp-core__src__pcs.rs','let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();'),
      ('active__hashline__src__gpu__cuda.rs','if *ml >= ntt.max_log {'),
      ('active__hashline__src__gpu__cuda.rs','pows: CudaSlice<u64>'),
      ('active__hashline__src__gpu__cuda.rs','let d_pows = dev.htod_sync_copy(as_u64s(pows))'),
      ('active__hashline__src__gpu__cuda.rs','let zk = ZkReenc { pads: d_pads, pows: d_pows, q };'),
      ('active__hashline__src__gpu__cuda.rs','plan_open_indices(idx, nn,'),
      ('active__hashline__src__gpu__mod.rs','pub mod open_plan {'),
    ]
    found=[]
    for file,fragment in fragments:
        text=(src/file).read_text();ck(fragment in text)
        found.append(dict(file=file,fragment=fragment,line=text[:text.index(fragment)].count('\n')+1))
    rows=[]
    for t,lc in [(32,13),(64,13),(128,14)]:
        for l in [1,2,32]:
            for r in [1,2,4,8]:
                for deferred in [False,True]:
                    for cached in [False,True]:rows.append(trace(t,lc,l,r,cached,deferred))
    # Eviction is a cache-capacity choice, not authorization to invalidate live opens.
    evict=trace(128,14,32,8,True,True,True)
    ck(evict['device_uploads']==8)
    grow=Capacity(True)
    grow.get('small',32);grow.get('large',64)
    ck(grow.peak==96);grow.evict();ck(sum(grow.objs.values())==96)
    grow.free('small');ck(sum(grow.objs.values())==64)
    grow.free('large');ck(not grow.objs)
    (ROOT/'capacity-growth-events.json').write_text(json.dumps(grow.events,indent=2)+'\n')
    # The trace's independent identities are counts, not native observed launches.
    for x in rows:
        nn=4*(1<<x['lc']);r=x['passes'];l=x['layers']
        ck(x['device_uploads']==(1 if x['cached'] else r*(3*l+1)))
        ck(x['host_builds']==(1 if x['cached'] else r*(4*l+1)))
        ck(x['selected_device_peak_B']==8*nn*(1 if x['cached'] or not x['deferred'] else (4 if l==1 else 5)))
    (ROOT/'trace-ledger.json').write_text(json.dumps(rows+[evict])+'\n')
    compact=[{k:v for k,v in x.items() if k not in ['requests','device_events','host_events']} for x in rows if x['tokens']==128 and x['layers']==32 and x['deferred']]
    result=dict(status='PASS',checks=checks,source_fragments=found,trace_rows=len(rows)+1,
                summary_T128_L32_deferred=compact,wall_seconds=time.monotonic()-start,
                rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                scope='Conditional public coset owner incidence/capacity only. GPU offered paths may decline; not observed native launches, actual fit, peak or time. M CPU-only. No T512 admission assumed.')
    (ROOT/'census-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':run()
