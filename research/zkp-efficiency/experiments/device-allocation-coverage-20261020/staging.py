"""Synthetic queue/lifetime experiment for optional host-backed FZC construction.
No CUDA, tensor contents, native proofs or downloaded code. Two buffers reused
only after an explicit completion boundary; model clocks are not speed evidence.
"""
import hashlib, json, os, pathlib, resource, struct, time
HERE=pathlib.Path(__file__).resolve().parent
P=2**64-2**32+1
SEED=2026102093
def word(seed,table,component,i):
    boundary=[0,1,P-1,P-2,2**32,2**63]
    if i<6: return (boundary[i]+17*table+3*component+seed)%P
    return (seed*0x9e3779b1+(table+1)*0x85ebca6b+component*0xc2b2ae35+i*0x27d4eb2f+i*i)%P
def digest(tables):
    h=hashlib.sha256()
    for t in tables:
        for a,b in t: h.update(struct.pack('<QQ',a,b))
    return h.hexdigest()
def run(n,res_a,res_h,supp,seed,mode):
    l=1<<n; k=21 if supp else 20
    tables=[None]*17; queue=[]; held=[]; reusable=[]; live=peak=volume=allocs=syncs=copy_syncs=0; events=[]
    def alloc():
        nonlocal live,peak,volume,allocs
        b={'id':allocs,'words':[P-1]*(l+3),'live':True}; allocs+=1
        live+=(l+3)*8; volume+=(l+3)*8; peak=max(peak,live); events.append(['alloc',b['id'],(l+3)*8]); return b
    def sync(copy=False):
        nonlocal syncs,copy_syncs
        if copy: copy_syncs+=1
        else: syncs+=1
        events.append(['sync',len(queue),'copy' if copy else 'explicit'])
        for t,bufs in queue:
            if not all(b['live'] for b in bufs): raise ValueError('use after completion owner released')
            tables[t]=[(bufs[0]['words'][i],0 if len(bufs)==1 else bufs[1]['words'][i]) for i in range(l)]
        queue.clear()
    for t in range(17):
        pair=t>=11; resident=res_h if pair else res_a
        if resident:
            tables[t]=[(word(seed,t,0,i),word(seed,t,1,i) if pair else 0) for i in range(l)]; continue
        count=2 if pair else 1
        if mode=='baseline': bufs=[alloc() for _ in range(count)]; held.extend(bufs)
        else:
            while len(reusable)<count: reusable.append(alloc())
            bufs=reusable[:count]
            if mode=='alias' and pair: bufs=[reusable[0],reusable[0]]
        for c,b in enumerate(bufs):
            # The pinned cudarc copy_into enqueues on the same stream and
            # waits. Simulating preceding reads before the immediate write
            # gives the same happens-before relation for these buffers.
            if mode in ['baseline','safe','ordered','alias','early-free']:
                sync(copy=True)
            b['words'][:l]=[word(seed,t,c,i) for i in range(l)]
            events.append(['upload',b['id'],t,c,l*8])
        queue.append((t,bufs)); events.append(['read-enqueue',t,[b['id'] for b in bufs]])
        if mode in ['safe','alias']: sync()
        if mode=='early-free':
            for b in bufs: b['live']=False
    sync()
    # Check only the 17 tables this change writes. Eq/support/derived/kernel,
    # transcript/challenges/masking and all proof obligations remain untested.
    return dict(hash=digest(tables),staging_peak_bytes=peak,staging_volume_bytes=volume,allocations=allocs,explicit_syncs=syncs,copy_syncs=copy_syncs,bytes_h2d=(11*(not res_a)+12*(not res_h))*l*8,events=events,source_word_slots=l,k=k,kd=k+1+int(supp))
def main():
    t=time.perf_counter(); rows=[]; errors=[]
    for n in [1,2,3,4,6,8]:
        for a,h in [(False,False),(True,False),(False,True),(True,True)]:
            for supp in [False,True]:
                for offset in [0,1,19]:
                    seed=SEED+offset; args=dict(n=n,res_a=a,res_h=h,supp=supp,seed=seed)
                    variants={m:run(**args,mode=m) for m in ['baseline','safe','ordered','unsafe','alias']}
                    assert variants['baseline']['hash']==variants['safe']['hash']
                    assert variants['baseline']['hash']==variants['ordered']['hash']
                    assert variants['baseline']['copy_syncs']==variants['ordered']['copy_syncs']
                    assert variants['baseline']['explicit_syncs']==variants['ordered']['explicit_syncs']
                    staged=not (a and h)
                    if staged: assert variants['baseline']['hash']!=variants['unsafe']['hash']
                    if not h: assert variants['baseline']['hash']!=variants['alias']['hash']
                    try: run(**args,mode='early-free')
                    except ValueError: rejected=True
                    else: rejected=False
                    assert rejected==staged
                    rows.append(dict(fixture=args,variants=variants,early_free_rejected=rejected))
    # Allocation-free public geometry projection; n20 is not a token context.
    projections=[]
    for n in [16,18,20,22]:
        l=1<<n
        projections.append(dict(n=n,table_entries=l,all_host_source_bytes=184*l,two_buffer_source_bytes=16*l,source_saving_bytes=168*l,split_supp_table_bytes=23*l*16,conservative_extra_explicit_syncs=17,ordered_extra_explicit_syncs=0,copy_syncs_all_host=23,all_resident_saving_bytes=0))
    (HERE/'staging-events.json').write_text(json.dumps(rows,separators=(',',':'))+'\n')
    r=dict(status='GENERATED',fixtures=len(rows),seed=SEED,projections=projections,wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=len(list(pathlib.Path('/proc/self/task').iterdir())),affinity=sorted(os.sched_getaffinity(0)),scope='synthetic table-byte and capacity model; zero native/proof/GPU evidence')
    (HERE/'staging-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
if __name__=='__main__': main()
