"""Independent Euclid/Fermat/DFT/polynomial oracle; no producer imports."""
from pathlib import Path
import hashlib,json,resource,time
HERE=Path(__file__).resolve().parent
MOD=18446744069414584321

def euclid_inverse(a):
    u,v=1,0;b=MOD
    while b:
        q=a//b;a,b=b,a-q*b;u,v=v,u-q*v
    assert a==1
    return u%MOD

def dft_inverse(row):
    n=len(row);omega=pow(7,(MOD-1)//n,MOD)
    # Direct definition, independent of butterfly indexing and scale formula.
    return [sum(x*pow(omega,(-i*j)%(MOD-1),MOD) for j,x in enumerate(row))*euclid_inverse(n)%MOD for i in range(n)]

def evaluate(coeff,x):
    value=0
    for c in reversed(coeff):value=(value*x+c)%MOD
    return value

def run():
    t=time.monotonic();checks=0
    def ck(x):
        nonlocal checks
        assert x;checks+=1
    for k in range(33):
        n=2**k
        # Division-based oracle and full Fermat exponentiation.
        a=euclid_inverse(n);b=pow(n,MOD-2,MOD)
        ck(a==b);ck((n*a)%MOD==1)
        claimed=MOD-((MOD-1)>>k);ck(a==claimed)
    fixtures=json.loads((HERE/'fixtures.json').read_text())
    positions=0;overlaps=0;controls=[]
    for f in fixtures:
        n=f['n'];nn=n*f['rate'];q=f['q'];co=dft_inverse(f['msg'])
        poly=co+[0]*(nn-n)
        # Add the two polynomial contributions, no ordered overwrite loop.
        for i in range(q):
            poly[i]=(poly[i]-f['pad'][i])%MOD
            poly[n+i]=(poly[n+i]+f['pad'][i])%MOD
        root=pow(7,(MOD-1)//nn,MOD)
        out=[evaluate(poly,f['h']*pow(root,j,MOD)%MOD) for j in range(nn)]
        ck(out==f['encoded']);positions+=nn;overlaps+=q>n
        raw=b''.join(x.to_bytes(8,'little') for x in out)
        ck(hashlib.sha256(raw).hexdigest()==f['encoded_sha256'])
    # Explicit nontrivial fixtures make normalizer controls decisive.
    f=next(x for x in fixtures if x['kind']=='random' and x['n']==8 and x['q']==8 and x['rate']==4)
    co=dft_inverse(f['msg']);omega=pow(7,(MOD-1)//8,MOD)
    ck([evaluate(co,pow(omega,j,MOD)) for j in range(8)]==f['msg'])
    ck([x*euclid_inverse(16)%MOD for x in co]!=co);controls.append('wrong_size_or_double_scale')
    ck([evaluate(co,pow(omega,-j,MOD)) for j in range(8)]!=f['msg']);controls.append('wrong_root_direction')
    ck(overlaps>0);controls.append('q_greater_than_n_included_CPU_only')
    pins=json.loads((HERE/'source-pins.json').read_text())
    for p in pins:
        ck(hashlib.sha256((HERE/p['copy']).read_bytes()).hexdigest()==p['sha256'])
    ledger=json.loads((HERE/'batch-ledger.json').read_text())
    for x in ledger:
        n=x['message_n'];r=x['rows'];c=x['chunk_rows'];lg=x['log_n']
        # Independent explicit chunk partition and operation ledger.
        sizes=[min(c,r-i) for i in range(0,r,c)]
        ck(len(sizes)==x['device_host_inverse_calls']);ck(sum(sizes)==r)
        ops=sum(1+((18446744069414584319>>bit)&1) for bit in range(64))
        ck(ops==127);ck(x['cpu_removed_source_muls']==r*ops)
        ck(x['device_host_removed_source_muls']==len(sizes)*ops)
        remaining=n*lg//2+n+(n+min(n,256))+(4*n)*(lg+2)//2
        ck(abs(x['cpu_complete_row_encode_multiply_share']-ops/(remaining+ops))<1e-15)
        ck(x['removed_device_launches']==x['removed_device_bytes']==x['removed_device_transfers']==0)
    schedules=json.loads((HERE/'schedule-ledger.json').read_text())
    for x in schedules:
        events=[]
        for _ in range(x['passes']):
            events.extend(['E0','E1'])
            for layer in range(x['layers']):
                if layer+1<x['layers']:events.append('boundary')
                events.extend(['A','H'])
        ck(len(events)==x['hypothetical_resident_commit_inverse_calls'])
        ck(len(events)*127==x['hypothetical_removed_host_muls'])
    r=dict(status='PASS',checks=checks,synthetic_rows=len(fixtures),encoded_positions=positions,
           overlap_rows=overlaps,source_pins=len(pins),negative_controls=controls,
           independent_batch_cases=len(ledger),independent_schedules=len(schedules),
           wall_seconds=time.monotonic()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
           scope='Independent original-data direct DFT/explicit polynomial only; no native receipt verification')
    (HERE/'validation-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))

if __name__=='__main__':run()
