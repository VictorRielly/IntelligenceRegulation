"""Independent destination-indexed byte oracle and requested-allocation ledger.

Does not import the Rust analogue, prior schedule code, or Python fixture code.
Allocation validation uses observed pointer ownership and independent formulas;
no conclusion relies on the compiler being obliged to preserve allocations.
"""
import copy, hashlib, json, os, platform, resource, time
from collections import Counter
from pathlib import Path
HERE=Path(__file__).resolve().parent
START=time.perf_counter()
checks=0
def check(condition, message):
    global checks
    checks+=1
    assert condition, message

EXPECTED=[(4,1,4,25,[0,1,2,3]),(3,2,4,13,[0,2,3]),
          (3,1,4,29,[3,0,2]),(2,1,8,17,[1,0]),(1,1,4,7,[0]),
          (5,2,2,11,[6,0,3,1,5]),(4,2,16,97,[2,0,3,1]),
          (32,8,4,448,list(range(32)))]
def geometry(row):
    q,k,h,f,slots=EXPECTED[row['case']]
    assert (q,k,h,f,slots)==(row['qh'],row['kvh'],row['hd'],row['f'],row['slots'])
    d=q*h; dp=1 << ((max(slots)+1)*h-1).bit_length(); fp=1 << (f-1).bit_length()
    assert (d,dp,fp)==(row['d'],row['dp'],row['fp'])
    kv=k*h
    return [(d,d,dp,dp),(kv,d,kv,dp),(kv,d,kv,dp),(d,d,dp,dp),(1,d,1,dp),
            (1,d,1,dp),(d,f,dp,fp),(d,f,dp,fp),(f,d,fp,dp)]

def oracle(row):
    """Walk every destination; invert the head slots, not the source scatter."""
    shapes=geometry(row); h=row['hd']; slots=row['slots']
    reverse={slot:head for head,slot in enumerate(slots)}
    blobs=[]
    for i,(to,ti,po,pi) in enumerate(shapes):
        b=bytearray(po*pi)
        for dst in range(po*pi):
            ro,ci=divmod(dst,pi)
            o=(reverse.get(ro//h,-999)*h+ro%h) if i==0 else ro
            j=(reverse.get(ci//h,-999)*h+ci%h) if i==3 else ci
            if 0<=o<to and 0<=j<ti:
                b[dst]=(row['seed']+row['case']*101+(o*ti+j)*73+i*19)%256
        blobs.append(bytes(b))
    return blobs

def ledger(row):
    mode=row['mode'];shapes=geometry(row)
    raw=[a*b for a,b,_,_ in shapes];out=[c*d for _,_,c,d in shapes]
    maps=[c*row['option_usize_bytes']+b*row['usize_bytes'] for _,b,c,_ in shapes]
    sizes={1:raw,2:out,3:[c*row['option_usize_bytes'] for _,_,c,_ in shapes],
           4:[b*row['usize_bytes'] for _,b,_,_ in shapes],5:out}
    live={};peak=0;decode_peak=0;volume=0;allocs=Counter();visits=[]
    for kind,ptr,size,phase in row['events']:
        if kind==1:
            index=phase//10-1;cl=phase%10
            assert 0<=index<9 and cl in sizes
            assert size==sizes[cl][index] and ptr and ptr not in live
            live[ptr]=(size,index,cl);volume+=size;allocs[cl]+=1
        elif kind==2:
            assert ptr in live and live[ptr][0]==size
            del live[ptr]
        elif kind==3:
            index=size
            current={v[1] for v in live.values() if v[2]==1}
            if mode==0: expected=set(range(0 if index<5 else 5,index+1))
            elif mode in [1,4]: expected={index}
            elif mode==2: expected=set(range(5 if index<5 else 9))
            else: expected=set()
            assert current==expected,(index,current,expected)
            assert not any(v[2] in [3,4,5] for v in live.values())
            assert {v[1] for v in live.values() if v[2]==2}==set(range(index))
            visits.append(sum(v[0] for v in live.values() if v[2]==1))
        else: raise AssertionError('unexpected realloc/unknown event')
        peak=max(peak,sum(v[0] for v in live.values()))
        decode_peak=max(decode_peak,sum(v[0] for v in live.values() if v[2]==1))
    assert len(visits)==9
    expected_counts=Counter({2:9,3:9,4:9})
    if mode!=3: expected_counts[1]=9
    if mode==4: expected_counts[5]=9
    assert allocs==expected_counts
    assert sorted((v[1],v[2]) for v in live.values())==[(i,5 if mode==4 else 2) for i in range(9)]
    # Formula independent of allocation event replay: phase envelope is retained
    # padded prefix + scope-specific decoded bytes + both current maps.
    if mode in [1,4]: decodes=raw
    elif mode==0: decodes=[sum(raw[(0 if i<5 else 5):i+1]) for i in range(9)]
    elif mode==2: decodes=[sum(raw[:5 if i<5 else 9]) for i in range(9)]
    else: decodes=[0]*9
    prediction=max(sum(out[:i+1])+decodes[i]+maps[i] for i in range(9))
    if mode==4: prediction=max(prediction,2*sum(out))
    assert peak==prediction,(peak,prediction)
    assert decode_peak==max(decodes)
    assert visits==decodes
    assert volume==sum(out)+sum(maps)+(sum(raw) if mode!=3 else 0)+(sum(out) if mode==4 else 0)
    return dict(peak_requested_bytes=peak,peak_decode_bytes=decode_peak,
                allocation_count=sum(allocs.values()),allocated_bytes=volume,
                live_at_return_bytes=sum(v[0] for v in live.values()),
                decode_visits=visits,counts_by_class=dict(allocs),formula_peak=prediction,
                raw9_bytes=sum(raw),padded9_bytes=sum(out))

def rejects(row):
    try: ledger(row)
    except AssertionError: return True
    return False

summaries=[];corruptions=0;event_controls=0;masquerades=0
commands=json.loads((HERE/'commands.json').read_text())
for opt in [0,3]:
    cmd=next(c for c in commands if c['name']==f'probe{opt}')
    rows=[json.loads(s) for s in (HERE/cmd['stdout']).read_text().splitlines()]
    check(len(rows)==40,'40 observed cases per compiler mode')
    for row in rows:
        check(row['seed']==2026101991 and row['threads']==1,'seed/thread evidence')
        expected=oracle(row);blob=(HERE/f'outputs-o{opt}'/row['output']).read_bytes()
        check(blob==b''.join(expected),'all nine padded matrices')
        cursor=0
        for b in expected:
            changed=bytearray(blob); changed[cursor+len(b)//2]^=1
            check(changed!=b''.join(expected),'corrupted output detected')
            corruptions+=1;cursor+=len(b)
        result=ledger(row)
        check(result['formula_peak']==result['peak_requested_bytes'],'independent formula')
        summaries.append(dict(opt=opt,case=row['case'],mode=row['mode'],**result,
                              output_sha256=hashlib.sha256(blob).hexdigest()))
        for mutation in ['size','missing-alloc','missing-free']:
            bad=copy.deepcopy(row)
            target=next(i for i,e in enumerate(bad['events']) if e[0]==(2 if mutation=='missing-free' else 1))
            if mutation=='size':bad['events'][target][2]+=1
            else:bad['events'].pop(target)
            check(rejects(bad),'allocation ledger mutation rejected '+mutation);event_controls+=1
        if row['mode'] in [2,4]:
            bad=copy.deepcopy(row);bad['mode']=1
            check(rejects(bad),'reference/clone negative rejected as scopes');masquerades+=1
    for case in range(8):
        by={s['mode']:s for s in summaries if s['opt']==opt and s['case']==case}
        check(len({s['output_sha256'] for s in by.values()})==1,'five variants byte-equal')
        check(by[0]['allocated_bytes']==by[1]['allocated_bytes'],'scopes remove no allocated volume')
        check(by[0]['allocation_count']==by[1]['allocation_count']==36,'same four allocations per matrix')
        check(by[2]['peak_decode_bytes']>by[0]['peak_decode_bytes']>by[1]['peak_decode_bytes'],'lifetime negative')
        check(by[0]['peak_requested_bytes']>by[1]['peak_requested_bytes'],'scopes reduce local region peak')
        check(by[3]['allocation_count']==27 and by[3]['peak_decode_bytes']==0,'direct-byte control')
        check(by[4]['allocation_count']==45,'clone negative')
for case in range(8):
    for mode in range(5):
        a,b=[s for s in summaries if s['case']==case and s['mode']==mode]
        check({k:v for k,v in a.items() if k!='opt'}=={k:v for k,v in b.items() if k!='opt'},'opt0/3 match')

native=(HERE/'native-trained_block.rs').read_text()
probe=(HERE/'probe.rs').read_text()
decode_body='''    fn i8s(&self) -> Vec<i8> {
        self.bytes.iter().map(|b| *b as i8).collect()
    }'''
check(decode_body in native and decode_body in probe,'original Vec API/body')
check('impl Drop' not in probe and 'black_box' not in probe.replace('black_box,',''),'no forced wrapper allocations')
check(native.count('pad_matrix(&')>=9,'native grouped seam')

cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name'))
result=dict(status='PASS',checks=checks,observed_regions=len(summaries),fixtures=8,compiler_optimization_levels=[0,3],
            byte_vector_comparisons=720,output_corruption_controls=corruptions,
            allocation_event_controls=event_controls,masquerade_controls=masquerades,
            seed=2026101991,summaries=summaries,wall_seconds=time.perf_counter()-START,
            rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,
            affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),cpu=cpu,platform=platform.platform(),
            new_full_stack_proofs=0,new_passes=0,new_proved_positions=0,device=None,proof_context=None,
            steady_rate=None,total_rate=None,startup_fraction=None,witness_seconds=None,proof_seconds=None,
            serialization_seconds=None,verification_seconds=None,
            scope='Observed requested allocations for scalar synthetic Rust analogue only. No allocator usable bytes, RSS savings, Rayon, native loader or complete proof measured.')
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='summaries'},indent=2))
print('8B-ratio reduced proxy,not target-size arrays:')
for row in summaries[-5:]:print(json.dumps(row))
