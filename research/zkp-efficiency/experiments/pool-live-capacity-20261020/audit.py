"""Independent offline reference: request obligations + allocation intervals.

Does not import or call capacity_model. Checks every reported decision and
snapshot, and deliberately corrupts evidence to test the checker.
"""
import copy, json, os, pathlib, resource, time
HERE=pathlib.Path(__file__).resolve().parent


def audit(case):
    # Allocation lifetime records retain freed objects; capacity is recomputed
    # from intervals instead of an incrementally maintained byte counter.
    records={}; idle=[]; owners={}; pending=[]; next_id=1
    reuse=True; cap=0; armed=None; peak=0; checks=0
    counts=dict(fresh_count=0,fresh_bytes=0,reuse_count=0,reuse_capacity_bytes=0,
                reuse_requested_bytes=0,raw_count=0,raw_bytes=0)
    def ensure(v, msg):
        nonlocal checks
        checks += 1
        assert v, f"{case['name']}: {msg}"
    def physical(at):
        return sum(v['capacity'] for v in records.values() if v['born'] <= at and (v['dead'] is None or v['dead'] > at))
    def release(obj, at, effects):
        if case['deferred']:
            pending.append(obj);effects.append(dict(kind='pending',id=obj))
        else:
            records[obj]['dead']=at;effects.append(dict(kind='free',id=obj))
    def sync(at,effects):
        for obj in pending:
            records[obj]['dead']=at;effects.append(dict(kind='free',id=obj))
        pending.clear()
    for step,event in enumerate(case['events']):
        command=event['command'];op=command['op']; expected=[]; status='ok'; selected=None
        if op in ('take','raw'):
            request=command['bytes'];name=command['name']
            ensure(name not in owners and request>0,'invalid input ownership/request')
            fitting=[]
            if op=='take' and reuse:
                for pos,obj in enumerate(idle):
                    size=records[obj]['capacity']
                    if size==request or (command['mode']=='min' and size>=request):
                        fitting.append((size,pos,obj))
            if fitting:
                size,pos,selected=sorted(fitting)[0]
                ensure(event['selected']==selected,'wrong best-fit/exact identity')
                idle[pos:pos+1]=[idle[-1]];idle.pop()
                owners[name]=selected;records[selected]['requested']=request
                counts['reuse_count']+=1;counts['reuse_capacity_bytes']+=size;counts['reuse_requested_bytes']+=request
                expected=[dict(kind='reuse',id=selected,name=name,requested=request)]
            else:
                if op=='take' and cap and request>cap:
                    status='cap'
                else:
                    if op=='take':
                        old=counts['fresh_count'];counts['fresh_count']+=1
                        if old==armed:
                            status='injected';armed=None
                    if status=='ok' and physical(step)+request>case['budget']:
                        status='oom'
                    if status=='ok':
                        selected=next_id;next_id+=1;kind='pool' if op=='take' else 'raw'
                        records[selected]=dict(capacity=request,requested=request,kind=kind,born=step,dead=None)
                        owners[name]=selected
                        expected=[dict(kind='allocate',id=selected,name=name,bytes=request,allocation_kind=kind)]
                        if op=='take': counts['fresh_bytes']+=request
                        elif command.get('counted',True): counts['raw_count']+=1;counts['raw_bytes']+=request
        elif op=='drop':
            ensure(command['name'] in owners,'drop must own a live buffer')
            obj=owners.pop(command['name'])
            if records[obj]['kind']=='pool' and len(idle)<64:
                idle.append(obj);expected=[dict(kind='cache',id=obj)]
            else: release(obj,step,expected)
        elif op=='drain':
            for obj in idle: release(obj,step,expected)
            idle=[]
            if command.get('sync',False): sync(step,expected)
        elif op=='retain':
            # Independent selection over (capacity, original position), with
            # each allocation assignable to at most one future request.
            candidates=[(records[obj]['capacity'],pos,obj) for pos,obj in enumerate(idle)]
            chosen=set()
            for request in command['requests']:
                matches=sorted(x for x in candidates if x[2] not in chosen and
                    (x[0]==request['bytes'] or (request['mode']=='min' and x[0]>=request['bytes'])))
                if matches: chosen.add(matches[0][2])
            victims=[obj for obj in idle if obj not in chosen]
            idle=[obj for obj in idle if obj in chosen]
            for obj in victims: release(obj,step,expected)
            if victims and command.get('sync',False): sync(step,expected)
        elif op=='sync': sync(step,expected)
        elif op=='arm': counts['fresh_count']=0;armed=command['n']
        elif op=='cap': cap=command['bytes']
        elif op=='reuse': reuse=command['enabled']
        elif op=='reset': counts={k:0 for k in counts}
        else: ensure(op=='snapshot','unknown operation')
        ensure(event['status']==status,'wrong refusal/gate result')
        ensure(event['selected']==selected,'selected id on failed/other event')
        ensure(event['effects']==expected,'allocation/reuse/free effects differ')
        active=set(owners.values())
        ensure(len(active)==len(owners),'aliased ownership')
        ensure(not(active & set(idle)) and not(active & set(pending)) and not(set(idle)&set(pending)),'ownership sets overlap')
        alive={obj for obj,v in records.items() if v['dead'] is None}
        ensure(alive==active|set(idle)|set(pending),'unclassified capacity/leak')
        live_pool=sum(records[obj]['capacity'] for obj in active if records[obj]['kind']=='pool')
        raw=sum(records[obj]['capacity'] for obj in active if records[obj]['kind']=='raw')
        cached=sum(records[obj]['capacity'] for obj in idle)
        awaiting=sum(records[obj]['capacity'] for obj in pending)
        now=physical(step);peak=max(peak,now)
        ensure(now==live_pool+raw+cached+awaiting,'capacity conservation')
        ensure(now<=case['budget'],'allocation exceeded budget')
        expected_snapshot=dict(live_pooled_bytes=live_pool,live_raw_bytes=raw,idle_pooled_bytes=cached,
                               pending_release_bytes=awaiting,physical_bytes=now,peak_physical_bytes=peak,
                               idle_count=len(idle),live_requested_bytes=sum(records[obj]['requested'] for obj in active),stats=counts.copy())
        ensure(event['snapshot']==expected_snapshot,'snapshot/counters/interval peak differ')
    return checks


def run():
    t=time.perf_counter(); data=json.loads((HERE/'events.json').read_text());cases=data['cases']
    checks=sum(audit(c) for c in cases);controls=0; summaries=[]
    for c in cases:
        last=c['events'][-1]['snapshot'];summary=dict(name=c['name'],peak_bytes=last['peak_physical_bytes'],
            final_bytes=last['physical_bytes'],idle_bytes=last['idle_pooled_bytes'],idle_count=last['idle_count'],
            fresh_attempts=last['stats']['fresh_count'],fresh_bytes=last['stats']['fresh_bytes'],
            reuse_events=last['stats']['reuse_count'],reuse_capacity_bytes=last['stats']['reuse_capacity_bytes'],
            reuse_requested_bytes=last['stats']['reuse_requested_bytes'],raw_count=last['stats']['raw_count'],
            raw_bytes=last['stats']['raw_bytes'],failures=[dict(step=i,status=e['status']) for i,e in enumerate(c['events']) if e['status']!='ok'])
        summaries.append(summary)
        # Every scenario must reject seven independent accounting corruptions.
        for field in ['physical_bytes','idle_pooled_bytes','live_pooled_bytes','live_raw_bytes','pending_release_bytes','peak_physical_bytes','live_requested_bytes']:
            bad=copy.deepcopy(c);bad['events'][-1]['snapshot'][field]+=8
            try: audit(bad)
            except AssertionError: controls+=1
            else: raise AssertionError('undetected '+field)
        alloc_index=next((i for i,e in enumerate(c['events']) if e['effects']),None)
        if alloc_index is not None:
            for mode in ['remove_effect','wrong_identity','counter']:
                bad=copy.deepcopy(c);event=bad['events'][alloc_index]
                if mode=='remove_effect': event['effects']=[]
                elif mode=='wrong_identity': event['selected']=1000000
                else: event['snapshot']['stats']['fresh_count']+=1
                try: audit(bad)
                except AssertionError: controls+=1
                else: raise AssertionError('undetected '+mode)
    by={r['name']:r for r in summaries}
    ensure_assertions=0
    def ensure(value):
        nonlocal ensure_assertions
        ensure_assertions+=1;assert value
    tail=by['best-fit-tail-and-ties']
    ensure(tail['reuse_requested_bytes']==24 and tail['reuse_capacity_bytes']==2048)
    ensure(by['count-cap-is-not-byte-cap']['idle_count']==64)
    ensure(by['count-cap-is-not-byte-cap']['idle_bytes']==8*sum(2**25+i for i in range(64)))
    ensure(by['volume-versus-peak']['fresh_bytes']==40960 and by['volume-versus-peak']['peak_bytes']==1024)
    ensure(by['one-shot-reuse-raw-cap']['failures']==[dict(step=5,status='injected'),dict(step=8,status='cap')])
    deferred=next(c for c in cases if c['name']=='deferred-free-needs-sync')
    ensure(deferred['events'][4]['status']=='oom' and deferred['events'][6]['status']=='ok')
    ensure(deferred['events'][3]['snapshot']['idle_count']==0 and deferred['events'][3]['snapshot']['pending_release_bytes']==512)
    returned=next(c for c in cases if c['name']=='returned-resident-capacity')
    ensure(returned['events'][4]['status']=='injected')
    ensure(returned['events'][6]['snapshot']['stats']['reuse_capacity_bytes']==4096)
    ensure(returned['events'][6]['snapshot']['stats']['reuse_requested_bytes']==256)
    ensure(by['mixed-rows-drain1']['peak_bytes']<by['mixed-rows-drain0']['peak_bytes'])
    ensure(by['mixed-rows-drain1']['fresh_attempts']>by['mixed-rows-drain0']['fresh_attempts'])
    ensure(by['mixed-rows-retain-next']['peak_bytes']==by['mixed-rows-drain1']['peak_bytes'])
    ensure(by['mixed-rows-retain-next']['fresh_attempts']==by['mixed-rows-drain0']['fresh_attempts'])
    retain=next(c for c in cases if c['name']=='retain-multiplicity-and-live-guard')
    ensure(retain['events'][7]['snapshot']['live_pooled_bytes']==1024)
    ensure(retain['events'][7]['snapshot']['idle_count']==2)
    ensure(retain['events'][9]['snapshot']['stats']['reuse_count']==2)
    # Same public geometry, four independent commit/drop schedules. Drains may
    # remove reuse. This is a negative for indiscriminate additional draining.
    pairs=[]
    for c in cases:
        m=c.get('metadata')
        if m and m['scope'].startswith('constructed') and not m['drains']:
            name=c['name'];other=name[:-1]+'1';a=by[name];b=by[other]
            ensure(b['fresh_attempts']>=a['fresh_attempts'])
            ensure(b['peak_bytes']<=a['peak_bytes'])
            pairs.append(dict(rows=m['rows'],n=m['n'],compact=m['compact'],
                no_drain_peak_bytes=a['peak_bytes'],drain_peak_bytes=b['peak_bytes'],
                no_drain_fresh=a['fresh_attempts'],drain_fresh=b['fresh_attempts'],
                fresh_delta=b['fresh_attempts']-a['fresh_attempts']))
            # Key buffer is outside current RAW_ALLOC counter in the pinned body.
            ensure(a['raw_count']==12)
    output=dict(status='PASS',checks=checks+ensure_assertions,source_cases=len(cases),
        events=sum(len(c['events']) for c in cases),corruption_controls=controls,seed=data['seed'],
        geometry_pairs=pairs,summaries=summaries,
        wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        threads=len(list(pathlib.Path('/proc/self/task').iterdir())),affinity=sorted(os.sched_getaffinity(0)),nice=os.nice(0),
        native_proofs=0,verified_positions=0,scope='independent capacity-policy/interval audit only; native peak,bytes,privacy,speed unmeasured')
    (HERE/'result.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({k:v for k,v in output.items() if k not in ['summaries','geometry_pairs']}))
    print(json.dumps(pairs[-2:]))


if __name__=='__main__': run()
