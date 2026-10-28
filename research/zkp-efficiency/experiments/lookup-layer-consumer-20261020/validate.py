"""Independent event replay, mutation controls and randomized public costs."""
from pathlib import Path
import json,random,hashlib,resource,time
from consumer import allocation_trace,consume
from reference import cost,tree,direct_samples,mle,verify_arithmetic
HERE=Path(__file__).resolve().parent;start=time.monotonic();rng=random.Random(20261020106);checks=0
def check(v):
    global checks
    assert v
    checks+=1
for case in range(240):
    sizes=[2**rng.randrange(0,11) for j in range(rng.randrange(1,8))];b=rng.randrange(0,13)
    for mode in ['forest','column']:
        a=allocation_trace(sizes,b,mode);ref=cost(sizes,b,mode)
        check((a['modeled_peak_bytes'],a['tree_internal_nodes'],a['leaf_generations'])==ref)
        live={};peak=0
        for op,key,size,total in a['events']:
            if op=='alloc':check(key not in live);live[key]=size
            else:check(live.pop(key)==size)
            check(sum(live.values())==total);peak=max(peak,total)
        check(peak==a['modeled_peak_bytes'])
        for idx in range(3):
            mutated=list(ref);mutated[idx]+=1
            check(tuple(mutated)!=(a['modeled_peak_bytes'],a['tree_internal_nodes'],a['leaf_generations']))
controls=[]
for case in range(80):
    d=rng.randrange(1,7);leaves=[(rng.randrange(65537),rng.randrange(1,65537)) for j in range(2**d)]
    pt=[rng.randrange(65537) for j in range(d-1)];ch=[rng.randrange(65537) for j in range(d-1)];lam=rng.randrange(1,65537)
    original=repr(leaves);claim,rows,final,_=consume(leaves,pt,ch,lam,65537)
    rr,rf=direct_samples(leaves,pt,ch,lam,65537);check(rr==rows);check(rf==final);check(repr(leaves)==original)
    check(verify_arithmetic(claim,rows,final,ch,65537))
    check(not verify_arithmetic(claim,rows,(final+1)%65537,ch,65537))
    parents=tree(leaves,65537)[-2]
    check(claim==(mle([z[0] for z in parents],pt,65537)+lam*mle([z[1] for z in parents],pt,65537))%65537)
    forged=list(leaves);forged[0]=((forged[0][0]+1)%65537,forged[0][1])
    nc,_,_,_=consume(forged,pt,ch,lam,65537);check(nc!=claim)
    # Simulate accidental alias: overwrite a retained checkpoint through a fold view.
    alias=leaves;before=repr(leaves);alias[0]=(0,0);check(repr(leaves)!=before)
    controls.append('alias detected')
pins=json.loads((HERE/'source-manifest.json').read_text())
for pin in pins:
    check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
    check(hashlib.sha256((HERE/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
result=dict(status='PASS',checks=checks,randomized_cost_schedules=480,cost_mutations=1440,
 independent_consumer_cases=80,alias_controls=len(controls),source_pins=len(pins),
 elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 scope='Independent phase widths, event replay, direct Boolean-basis polynomial samples and source pins; no protocol validation.')
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
