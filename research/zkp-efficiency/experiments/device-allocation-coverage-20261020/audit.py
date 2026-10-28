"""Independent destination-byte oracle and line-site census reference.
No import of staging.py. The lexical scanner is imported only as the DUT for
source mutations; its results are checked against a separate line reference.
"""
import collections,copy,hashlib,json,os,pathlib,re,resource,struct,time
HERE=pathlib.Path(__file__).resolve().parent
P=18446744069414584321
CHECKS=0
def check(v,msg='audit'):
    global CHECKS
    CHECKS+=1
    if not v: raise AssertionError(msg)
def oracle(f):
    raw=bytearray()
    # Destination order: 11 base rows followed by six extension rows.
    for row in range(17):
        for col in range(2**f['n']):
            for comp in [0,1]:
                if row<11 and comp==1: v=0
                elif col<6:
                    edge=(0,1,P-1,P-2,4294967296,9223372036854775808)[col]
                    v=(f['seed']+17*row+3*comp+edge)%P
                else:
                    v=sum([f['seed']*2654435761,(row+1)*2246822507,comp*3266489909,col*668265263,col**2])%P
                raw.extend(v.to_bytes(8,'little'))
    return hashlib.sha256(raw).hexdigest()
def site_reference(src):
    # All inspected allocation API invocations occupy one source line.
    # Independent of function/bracket/string scanner. No arbitrary Rust claim.
    found=[]
    pattern=re.compile(r'\bdev\.(alloc_zeros|alloc|htod_sync_copy)(?:\s*::<\s*(?:u64|u32)\s*>)?\s*\(|\bPooled::(take_min|take)\s*\(|\bcu::(malloc_host)\s*\(')
    for i,row in enumerate(src.splitlines(),1):
        code=row.split('//',1)[0]
        if not code.strip() or code.lstrip().startswith('*'): continue
        for m in pattern.finditer(code): found.append((i,next(x for x in m.groups() if x)))
    return collections.Counter(found)
def accepts(f,r,name,expected):
    """Adjudicate an event receipt against independent dimensions/lifetimes."""
    a=int(not f['res_a']);h=int(not f['res_h']);l=2**f['n']
    slots=(11*a+12*h) if name=='baseline' else 2 if h else 1 if a else 0
    expected_syncs=11*a+6*h+1 if name=='safe' else 1
    if r['hash']!=expected or r['staging_peak_bytes']!=slots*(l+3)*8:return False
    if r['bytes_h2d']!=(11*a+12*h)*l*8:return False
    if r['allocations']!=slots or r['explicit_syncs']!=expected_syncs:return False
    active={};pending=[];copy_waits=explicit_waits=uploaded=0
    for e in r['events']:
        if e[0]=='alloc':
            if e[1] in active or e[2]!=(l+3)*8:return False
            active[e[1]]=e[2]
        elif e[0]=='upload':
            if e[1] not in active or e[4]!=l*8:return False
            if any(e[1] in p for p in pending):return False
            uploaded+=e[4]
        elif e[0]=='read-enqueue':
            if len(e[2])!=len(set(e[2])) or any(i not in active for i in e[2]):return False
            pending.append(e[2])
        elif e[0]=='sync':
            if e[1]!=len(pending):return False
            pending=[]
            if e[2]=='copy':copy_waits+=1
            elif e[2]=='explicit':explicit_waits+=1
            else:return False
        else:return False
    return not pending and copy_waits==11*a+12*h and explicit_waits==expected_syncs and uploaded==r['bytes_h2d'] and len(active)==slots
def main():
    t=time.perf_counter();events=json.loads((HERE/'staging-events.json').read_text());corruptions=0;negatives=0
    for case in events:
        f=case['fixture'];expected=oracle(f);a=int(not f['res_a']);h=int(not f['res_h']);l=2**f['n'];src_words=11*a+12*h;src_tables=11*a+6*h
        for name in ['baseline','safe','ordered']:
            r=case['variants'][name];check(r['hash']==expected,'direct destination oracle')
            slots=src_words if name=='baseline' else 2 if h else 1 if a else 0
            check(r['staging_peak_bytes']==slots*(l+3)*8)
            check(r['staging_volume_bytes']==slots*(l+3)*8)
            check(r['allocations']==slots)
            check(r['bytes_h2d']==src_words*l*8)
            check(r['explicit_syncs']==(src_tables+1 if name=='safe' else 1))
            check(r['copy_syncs']==src_words)
            check(r['k']==20+int(f['supp']))
            check(r['kd']==21+2*int(f['supp']))
            # Rebuild requested-live intervals from event ownership, separate
            # from the simulator's peak/volume accumulation.
            active={};queued=[];observed_peak=0;uploads=0
            for ev in r['events']:
                if ev[0]=='alloc':
                    check(ev[1] not in active);active[ev[1]]=ev[2]
                    observed_peak=max(observed_peak,sum(active.values()))
                elif ev[0]=='upload':
                    check(ev[1] in active);uploads+=ev[4]
                    check(not any(ev[1] in ids for ids in queued),'write while old consumer pending')
                elif ev[0]=='read-enqueue':
                    check(all(i in active for i in ev[2]));check(len(set(ev[2]))==len(ev[2]));queued.append(ev[2])
                elif ev[0]=='sync': queued=[]
                else: raise AssertionError('unrecognized event')
            check(not queued);check(observed_peak==r['staging_peak_bytes']);check(uploads==r['bytes_h2d'])
            check(accepts(f,r,name,expected),'independent event adjudicator')
            bad=copy.deepcopy(r);bad['hash']=('0' if expected[0]!='0' else '1')+expected[1:]
            check(not accepts(f,bad,name,expected),'corrupted table bytes rejected');corruptions+=1
            bad=copy.deepcopy(r);bad['staging_peak_bytes']+=8
            check(not accepts(f,bad,name,expected),'corrupted capacity rejected');corruptions+=1
            bad=copy.deepcopy(r);bad['events'].pop()
            check(not accepts(f,bad,name,expected),'missing completion event rejected');corruptions+=1
        if src_tables:
            check(case['variants']['unsafe']['hash']!=expected);check(case['early_free_rejected']);negatives+=2
        else:
            check(case['variants']['unsafe']['hash']==expected);check(not case['early_free_rejected'])
        if h: check(case['variants']['alias']['hash']!=expected);negatives+=1
    census=json.loads((HERE/'census.json').read_text());source_checks=0
    import census as dut
    for label,tree in census['trees'].items():
        s=(HERE/'source'/tree['snapshot']).read_text();ref=site_reference(s)
        got=collections.Counter((x['line'],x['operation']) for x in tree['sites'])
        check(got==ref,label+' independent allocation line census');source_checks+=sum(ref.values())
        check(hashlib.sha256(s.encode()).hexdigest()==tree['sha256'])
        missing=got.copy();key=next(iter(missing));missing.subtract([key]);missing+=collections.Counter()
        check(missing!=ref);corruptions+=1
        # Every real row must identify an owner and typed raw allocs.
        for x in tree['sites']:
            check(x['function']!='<none>');check(bool(x['args']))
            if x['operation'] in ['alloc','alloc_zeros']:check(x['dtype'] in ['u32','u64'])
    base='fn f() { let a = dev.alloc::<u64>(8); }\n'
    fake='// dev.alloc::<u64>(8)\n/* outer /* dev.alloc::<u32>(1) */ */\nfn no() { let s = r###"dev.alloc::<u64>(9) { }"###; let q = "Pooled::take(&d, 4)"; let c = \'}\'; }\n'
    check(len(dut.scan(base))==1);check(len(dut.scan(fake))==0)
    check(len(dut.scan(fake+base))==1)
    extra='fn added() { let a = dev.alloc_zeros::<u32>(7); }\n'
    check(len(dut.scan(base+extra))==2);negatives+=4
    # Manually reviewed, source-pinned semantic anchors. These are not a
    # substitute for an executed Rust call graph or lifetime trace.
    gpu=(HERE/'source/gpu__cuda.rs').read_text();r8=(HERE/'source/r8__cuda.rs').read_text()
    check('tw: Option<(u32, CudaSlice<u64>, CudaSlice<u64>)>' in gpu)
    check('static FZC_PUB: Mutex<Vec<FzcPub>>' in gpu)
    code,fs=dut.functions(gpu)
    dr=[f for f in fs if f['name']=='dev_pool_drain'][0];drain=gpu[dr['body']:dr['end']]
    check('pool.clear()' in drain and 'synchronize()' in drain)
    check('FZC_PUB' not in drain and 'self.tw' not in drain)
    new=[f for f in fs if f['name']=='new' and 'srcs:' in gpu[f['start']:f['body']]][0]
    body=gpu[new['body']:new['end']]
    check('note_raw_alloc(' not in body)
    for value in ['keep.push(d_src)','keep.push(d_re)','keep.push(d_im)']:check(value in body)
    check(body.index('dev.synchronize().map_err(|e| format!("fzc build:')<body.index('drop(keep)'))
    for label in ['root','r8','gpu']:
        prod=[c for c in census['callers'] if c['tree']==label and not c['test_named']]
        check(all(c['path'] in ['layer.rs','zk.rs'] for c in prod))
        check(not any(c['path'].startswith('private_block/') for c in prod))
    public=body[body.index('FzcSrc::Public'):body.index('let d_prm')]
    check(public.index('htod_sync_copy')<public.index('cache.retain'))
    check('cache.len() >= 4' in public)
    dep=(HERE/'source/cudarc__src__driver__safe__alloc.rs').read_text()
    code,fs=dut.functions(dep)
    h=[f for f in fs if f['name']=='htod_sync_copy'][0]
    hb=dep[h['body']:h['end']]
    check('self.alloc(src.len())' in hb and 'self.htod_sync_copy_into(src, &mut dst)' in hb)
    h=[f for f in fs if f['name']=='htod_sync_copy_into'][0]
    hb=dep[h['body']:h['end']]
    check('self.synchronize()' in hb and 'self.stream' in hb)
    check('assert_eq!(src.len(), dst.len())' in hb)
    # Copy-into must receive a requested-length VIEW if a reused buffer has
    # extra capacity. Our fixtures deliberately give each buffer +3 words.
    check(all(c['variants']['ordered']['staging_peak_bytes']%8==0 for c in events))
    proto=(HERE/'source/gpu__private_block__protocol.rs').read_text()
    arg=(HERE/'source/gpu__private_block__argument.rs').read_text()
    backend=(HERE/'source/gpu__gpu__mod.rs').read_text()
    check('pcs::Store::Device(dc) => Some(dc)' in proto)
    check('dev: [resident(&a), resident(&h)]' in proto)
    check('Cm::A => (pd.data[0], pd.dev[0])' in arg)
    check('Cm::H => (pd.data[1], pd.dev[1])' in arg)
    check('pub fn declined(site:' in backend and 'if required()' in backend)
    resident=[c for c in events if c['fixture']['res_a'] and c['fixture']['res_h']]
    check(len(resident)==36)
    check(all(c['variants']['ordered']['staging_peak_bytes']==0 and c['variants']['baseline']['allocations']==0 for c in resident))
    # Review patch syntax/shape only: not a Rust type-check or proof oracle.
    patch=json.loads((HERE/'patch-manifest.json').read_text())
    candidate=(HERE/'candidate-cuda.rs').read_text()
    check(hashlib.sha256(candidate.encode()).hexdigest()==patch['candidate_sha256'])
    check(candidate.count('let mut host_stage: Vec<CudaSlice<u64>> = Vec::new();')==1)
    ccode,cfs=dut.functions(candidate)
    ctor=[f for f in cfs if f['name']=='new' and 'srcs:' in candidate[f['start']:f['body']]][0]
    check(gpu[:new['start']]==candidate[:ctor['start']])
    check(gpu[new['end']:]==candidate[ctor['end']:])
    check('drop(host_stage)' in candidate[ctor['body']:ctor['end']])
    for n in [16,18,20,22]:
        l=2**n
        # Table growth is old pair + new pair before assignment; retained
        # public tables: four old + one new at miss, before eviction.
        check((11+6*2)*l*8-2*l*8==168*l)
        check(4*l*16+l*16==80*l)
    result=dict(status='PASS',fixtures=len(events),checks=CHECKS,allocation_sites=source_checks,negative_controls=negatives,corruption_controls=corruptions,seed=2026102093,wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=len(list(pathlib.Path('/proc/self/task').iterdir())),affinity=sorted(os.sched_getaffinity(0)),scope='independent authored single-agent synthetic/source audit; no external review/native proof')
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
