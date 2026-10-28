"""Independent reference, no producer import; event interval reconstruction."""
from pathlib import Path
import hashlib,json,resource,time
R=Path(__file__).resolve().parent;P=18446744069414584321
checks=0
def ck(x):
    global checks
    assert x
    checks+=1
def row_reference(f):
    n=f['n'];nn=n*f['rate'];wi=pow(pow(7,(P-1)//n,P),P-2,P)
    coefficients=[]
    for k in range(n):
        step=pow(wi,k,P);power=1;v=0
        for y in f['msg']:
            v=(v+y*power)%P;power=power*step%P
        coefficients.append(v*pow(n,P-2,P)%P)
    # Explicit coefficient construction of f_data+(X^n-1)g, independent of encode.
    poly=coefficients+[0]*(nn-n)
    for i,pad in enumerate(f['pad']):
        poly[i]=(poly[i]-pad)%P;poly[n+i]=(poly[n+i]+pad)%P
    root=pow(7,(P-1)//nn,P);out=[];x=f['h']
    for _ in range(nn):
        out.append(sum(v*pow(x,k,P) for k,v in enumerate(poly))%P)
        x=x*root%P
    return out
def run():
    t0=time.monotonic();fs=json.loads((R/'fixtures.json').read_text());positions=0
    for f in fs:
        reference=row_reference(f);ck(reference==f['encoded']);positions+=len(reference)
        # Changed pad must differ even if public powers are shared.
        other={**f,'pad':f['pad'].copy()};other['pad'][0]=(other['pad'][0]+1)%P
        ck(row_reference(other)!=f['encoded'])
    trace=json.loads((R/'trace-ledger.json').read_text());events=0
    for x in trace:
        L,Rp=x['layers'],x['passes'];nn=4*2**x['lc'];cached=x['cached']
        # Derive role counts by enumerating roles rather than copying formulas.
        roles=[y['role'].split(':',1)[1][0] for y in x['requests']]
        ck(roles.count('E')==2*Rp);ck(roles.count('B')==(L-1)*Rp)
        for role in ['A','H','M']:ck(roles.count(role)==L*Rp)
        baseline_words=sum(4096 if role=='M' else nn for role in roles)
        ck(x['private_salt_bytes_unchanged']==32*baseline_words)
        if not cached:
            ck(x['cpu_public_words_built']==baseline_words)
            ck(x['device_powers_uploaded_B']==8*(baseline_words-4096*L*Rp))
        else:
            builds=Rp if x['evict_per_pass'] else 1
            ck(x['device_powers_uploaded_B']==builds*nn*8)
            ck(x['cpu_public_words_built']==builds*nn)
        # Reconstruct live leases by label. This independent oracle requires a
        # single fixed identity/capacity per row; variable grow is tested below.
        live=set();peak=0;uploaded=0;pinned=False
        for e in x['device_events']:
            kind,_,label=e['kind'].partition(':')
            if kind=='allocate':
                ck(label not in live);live.add(label);uploaded+=nn*8
                predicted=nn*8 if cached else len(live)*nn*8
                pinned=cached
            elif kind=='hit':
                ck(cached and pinned and label not in live);live.add(label);predicted=nn*8
            elif kind=='release':
                ck(label in live);live.remove(label)
                predicted=nn*8 if cached and pinned else len(live)*nn*8
            elif kind=='publish':predicted=nn*8 if cached else len(live)*nn*8
            elif kind=='evict':
                pinned=False;predicted=nn*8 if live and cached else len(live)*nn*8
            else:raise AssertionError(kind)
            ck(predicted==e['bytes']);peak=max(peak,predicted);events+=1
        ck(not live and peak==x['selected_device_peak_B'])
        ck(uploaded==x['device_powers_uploaded_B'])
    grow=json.loads((R/'capacity-growth-events.json').read_text())
    ck([e['bytes'] for e in grow]==[32,32,96,96,96,64,0])
    for pin in json.loads((R/'source-pins.json').read_text()):
        ck(hashlib.sha256((R/pin['copy']).read_bytes()).hexdigest()==pin['sha256'])
    # CPU-only M/direct NTT cache and transcript index plans are separate objects.
    src=R/'source';gpu=(src/'active__hashline__src__gpu__cuda.rs').read_text()
    p=gpu[gpu.index('fn ensure_twiddles('):gpu.index('fn ntt_rows(')]
    ck('if *ml >= ntt.max_log' in p)
    ck('plan_open_indices(idx, nn,' in gpu)
    ck('pows: CudaSlice<u64>' in gpu)
    output=dict(status='PASS',checks=checks,rows=len(fs),positions=positions,
                trace_rows=len(trace),capacity_events=events,source_pins=len(json.loads((R/'source-pins.json').read_text())),
                elapsed_s=time.monotonic()-t0,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                scope='Independent polynomial coefficients/evaluation and fixed-domain live-event oracle; no probe/census import or native verification')
    (R/'validation-result.json').write_text(json.dumps(output,indent=2)+'\n');print(json.dumps(output))
if __name__=='__main__':run()
