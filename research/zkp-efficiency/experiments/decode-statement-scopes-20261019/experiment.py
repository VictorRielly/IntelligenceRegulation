"""Synthetic exact byte oracle plus source-pinned allocation-free lifetime model.

Only temporary release boundaries differ. No native loader or proof execution.
The separately compiled local Rust Drop probe observes the language rule.
"""
import copy,difflib,hashlib,json,os,platform,re,resource,time
from pathlib import Path
H=Path(__file__).resolve().parent
SEED=2026101989 # inherited synthetic fixture seed; this schedule test uses no RNG
NAMES=['wq','wk','wv','wo','gamma_a','gamma_m','wg','wu','wd']
checks=0
def check(v):
    global checks
    assert v
    checks+=1
def sha(b): return hashlib.sha256(b).hexdigest()
def dims(s):
    d=s['qh']*s['hd'];k=s['kv']*s['hd'];dp=s['hp']*s['hd'];f=s['f'];fp=1<<(f-1).bit_length()
    return [(d,d,dp,dp,'q','i'),(k,d,k,dp,'i','i'),(k,d,k,dp,'i','i'),
      (d,d,dp,dp,'i','q'),(1,d,1,dp,'i','i'),(1,d,1,dp,'i','i'),
      (d,f,dp,fp,'i','i'),(d,f,dp,fp,'i','i'),(f,d,fp,dp,'i','i')]
def schedule(case,mode,fail=None):
    live={};outputs={};visits=[];peak=0;order=[]
    s=case['shape']
    def axis(i,tag):
        if tag=='i':return i
        head,lane=divmod(i,s['hd']);g,j=divmod(head,s['qh']//s['kv'])
        return (g*(s['hp']//s['kv'])+j)*s['hd']+lane
    try:
        for i,(name,ds) in enumerate(zip(NAMES,dims(s))):
            nr,nc,pr,pc,ra,ca=ds;raw=bytes.fromhex(case['arrays'][name]['hex'])
            # Explicit release bookkeeping models the Rust expression scopes.
            live[name]=[v if v<128 else v-256 for v in raw]
            if mode=='premature':del live[name]
            if name==fail:raise ValueError('injected_pad:'+name)
            if name not in live:raise ValueError('released_decode:'+name)
            peak=max(peak,sum(map(len,live.values())));visits.append(sum(map(len,live.values())))
            out=[0]*(pr*pc)
            for r in range(nr):
                for c in range(nc):out[axis(r,ra)*pc+axis(c,ca)]=live[name][r*nc+c]
            outputs[name]=out;order.append(name)
            if mode=='scoped':del live[name]
            elif mode=='grouped' and i in [4,8]:live.clear()
        live.clear()
        return dict(status='accept',outputs=outputs,visits=visits,peak_decode_bytes=peak,order=order)
    except ValueError as e:
        live.clear()
        return dict(status=str(e),order=order)
def event_trace(s,mode):
    ds=dims(s);raw=sum(a*b for a,b,*_ in ds)+2560
    rope=2*s['t']*(s['hd']//2)*8
    # Conservative background retained from previous envelope: two RoPE pairs
    # plus generated small tables; not a claim that all exist on every branch.
    background=raw+2*rope+2560
    live={};events=[];padded=0
    for i,(name,(nr,nc,pr,pc,*_)) in enumerate(zip(NAMES,ds)):
        live[name]=nr*nc
        padded+=pr*pc
        maps=16*pr+8*nc # x86_64 Option<usize> src_of + inner Vec<usize>
        events.append(dict(name=name,decode_names=list(live),decode_bytes=sum(live.values()),
          padded_bytes=padded,mapping_bytes=maps,total_bytes=background+padded+maps+sum(live.values())))
        if mode=='scoped':live.clear()
        elif i in [4,8]:live.clear()
    return dict(background_bytes=background,events=events,peak_bytes=max(e['total_bytes'] for e in events))
def accounting():
    s=dict(qh=32,kv=8,hp=32,hd=128,f=14336,t=128)
    before=event_trace(s,'grouped');after=event_trace(s,'scoped')
    ds=dims(s);raw=sum(a*b for a,b,*_ in ds)+2560
    pad=sum(pr*pc for _,_,pr,pc,*_ in ds);rope=2*128*64*8;pub=pad+rope+2560
    prior=json.loads((H/'prior-payload-ledger.json').read_text());rows=[]
    for old in prior['rows']:
        if old['decode_mode']!='native_decode':continue
        check(old['before_phase_bytes'][0]==before['peak_bytes'])
        for release in ['none','post','split']:
            b=old['before_phase_bytes'][:]
            if release=='post':b[-1]-=raw
            if release=='split':b[1]-=raw-2560;b[-1]-=raw
            a=b[:];a[0]=after['peak_bytes']
            resident=(old['pins']+1)*pub
            rows.append(dict(constructor=old['constructor'],hash_workers=old['hash_workers'],pins=old['pins'],
              full=old['full'],raw_release=release,before_phases=b,after_phases=a,
              before_bytes=max(b),after_bytes=max(a),saving_bytes=max(b)-max(a),
              before_with_current_next_pins_gib=(max(b)+resident)/2**30,
              after_with_current_next_pins_gib=(max(a)+resident)/2**30,
              limiting_phase=['pad','constructor','record' if old['full'] else 'return'][a.index(max(a))]))
    return dict(target_shape=s,raw11_bytes=raw,padded9_bytes=pad,public_block_bytes=pub,
      before=before,after=after,pad_saving_bytes=before['peak_bytes']-after['peak_bytes'],rows=rows,
      exclusions=['allocator/capacity slack','page cache','JSON/manifest','thread stacks',
      'witness/proof/serialization/device','extra evicted live leases'],
      scope='Allocation-free conservative public-payload model, not RSS/VRAM/hardware fit/time. Two RoPE pairs are a conservative background; padding/map/decode events follow source order.')
def patch():
    native=(H/'native/hashline__src__private_block__trained_block.rs').read_text()
    lo=native.index('        let aw = [');hi=native.index('        let public = AttentionPublic',lo)
    old=native[lo:hi];calls=re.findall(r'pad_matrix\(&\w+\.i8s\(\),[^)]*\)',old)
    check(len(calls)==9)
    check([re.search(r'&(\w+)\.i8s',x)[1] for x in calls]==['wq','wk','wv','wo','ga','gm','wg','wu','wd'])
    # Own the padded RESULT, never bind a reference to the decoded temporary.
    new='        // Separate call statements bound each decoded temporary to its semicolon.\n'
    for prefix,c in [('aw',calls[:5]),('fw',calls[5:])]:
        new+=''.join(f'        let {prefix}{i} = {call};\n' for i,call in enumerate(c))
        new+=f'        let {prefix} = ['+', '.join(f'{prefix}{i}' for i in range(len(c)))+'];\n'
    candidate=native[:lo]+new+native[hi:]
    (H/'candidate-trained_block.rs').write_text(candidate)
    (H/'review-only-statement-scopes.patch').write_text(''.join(difflib.unified_diff(native.splitlines(True),candidate.splitlines(True),
      fromfile='a/hashline/src/private_block/trained_block.rs',tofile='b/hashline/src/private_block/trained_block.rs')))
    check(native[:lo]==candidate[:lo]);check(native[hi:]==candidate[lo+len(new):])
    return dict(native_sha256=sha(native.encode()),candidate_sha256=sha(candidate.encode()),call_count=len(calls),
      patch_status='UNBUILT/UNAPPLIED production-loader diff; standalone authored language-rule probe was compiled separately')
def main():
    t=time.perf_counter();cases=json.loads((H/'prior-input-cases.json').read_text())
    previous=json.loads((H/'prior-fixtures.json').read_text());fixtures=[];control_count=0
    for case in cases:
        b=schedule(case,'grouped');a=schedule(case,'scoped');bad=schedule(case,'extended_refs')
        check(b['outputs']==a['outputs']==bad['outputs']);check(b['order']==a['order']==NAMES)
        sizes=[len(bytes.fromhex(case['arrays'][n]['hex'])) for n in NAMES]
        check(b['peak_decode_bytes']==max(sum(sizes[:5]),sum(sizes[5:])))
        check(a['peak_decode_bytes']==max(sizes));check(bad['peak_decode_bytes']==sum(sizes))
        check(a['peak_decode_bytes']<b['peak_decode_bytes']<bad['peak_decode_bytes'])
        check(schedule(case,'premature')['status']=='released_decode:wq');control_count+=1
        faults=[]
        for name in NAMES:
            fb=schedule(case,'grouped',name);fa=schedule(case,'scoped',name)
            check(fa==fb and fa['status']=='injected_pad:'+name);faults.append(fa);control_count+=1
        fixtures.append(dict(index=case['metadata']['index'],baseline=b,candidate=a,negative=bad,first_errors=faults))
    for old in previous:
        result=fixtures[old['case']['metadata']['index']]['candidate']['outputs']
        check(all(result[n]==old['result']['block'][n] for n in NAMES))
    ledger=accounting();pins=json.loads((H/'prior-source-pins.json').read_text())
    for p in pins:
        check(sha(Path(p['source']).read_bytes())==p['sha256'])
        check(sha((H/p['snapshot']).read_bytes())==p['sha256'])
    result=dict(status='PASS',checks=checks,synthetic_cases=len(cases),prior_accepted_paths_compared=len(previous),
      new_negative_controls=control_count,seed=SEED,seed_scope='Inherited cycle0089 fixture identity; no new RNG in deterministic schedule test',wall_seconds=time.perf_counter()-t,
      rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,nice=os.nice(0),
      affinity=sorted(os.sched_getaffinity(0)),hardware=platform.platform(),cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
      python=platform.python_version(),source_gate=patch(),new_full_stack_proofs=0,new_passes=0,new_proved_positions=0,
      device=None,proof_context=None,steady_rate=None,total_rate=None,startup_fraction=None,
      witness_seconds=None,proof_seconds=None,serialization_seconds=None,verification_seconds=None,
      scope='Synthetic padding/first-error schedules and conservative payload model only; standalone Rust Drop probe separate; no production native loader/proof executed')
    for n,v in [('fixtures.json',fixtures),('payload-ledger.json',ledger),('result.json',result)]:
        (H/n).write_text(json.dumps(v,indent=2)+'\n')
    print(json.dumps(result,sort_keys=True))
if __name__=='__main__':main()
