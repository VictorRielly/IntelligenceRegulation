from pathlib import Path
import json,time,resource
from frontier import model
HERE=Path(__file__).resolve().parent;start=time.monotonic()
fixtures=json.loads((HERE/'inputs.json').read_text());out=[];checks=0
for fixture in fixtures:
    sizes=fixture['sizes'];C=len(sizes);total=sum(sizes)
    for fmax in [12,14,15,16]:
        arms={}
        for mode in ['direct','batch','cached']:
            plans=[model(n,min(fmax,n.bit_length()-1),mode,C) for n in sizes]
            counts={k:sum(x['counts'][k] for x in plans) for k in plans[0]['counts']}
            # Root forest preparation precedes sequential column frontiers.
            counts['source_reads']+=total
            counts['build_muls']+=3*(total-1);counts['build_adds']+=total-1
            peak=max(plans,key=lambda x:x['peak_bytes'])
            arms[mode]=dict(counts=counts,peak_bytes=peak['peak_bytes'],peak_plan={k:peak[k] for k in ['n','f','B','peak_phase']})
        direct=arms['direct']
        for mode in ['batch','cached']:
            other=arms[mode]
            assert other['counts']['source_reads']==direct['counts']['source_reads'];checks+=1
            assert other['counts']['build_muls']>=direct['counts']['build_muls'];checks+=1
            assert other['peak_bytes']>=direct['peak_bytes'];checks+=1
            other['extra_vs_direct']={k:other['counts'][k]-direct['counts'][k] for k in direct['counts']}
        out.append({k:fixture[k] for k in ['model','T','dd','scope','old_U8_helper_bytes']}|dict(fmax=fmax,columns=C,original_leaves=total,arms=arms))
single=[model(2**21,f,mode,84) for f in [12,14,15,16] for mode in ['direct','batch','cached']]
(HERE/'capacity-events.json').write_text(json.dumps(single,indent=2)+'\n')
(HERE/'forest-result.json').write_text(json.dumps(dict(status='PASS',checks=checks,profiles=out,elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss),indent=2)+'\n')
print(json.dumps(dict(status='PASS',profiles=len(out),checks=checks,elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)))
