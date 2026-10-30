import hashlib, json, os, platform, random, resource, time
from dataclasses import replace
from pathlib import Path
import candidate as c
import reference as r

SEED = 202610290136
rng = random.Random(SEED)
begin = time.monotonic()
checks = 0
fixtures = []
controls = []

def check(value):
    global checks
    checks += 1
    assert value, checks

def field(): return (rng.randrange(c.P), rng.randrange(c.P))
def wire(values): return b''.join(x.to_bytes(8,'little')+y.to_bytes(8,'little') for x,y in values)

def exercise(sites, rho, data, es, large=False, label=''):
    initial = [field() for _ in sites]
    actual, cache = c.extension_terms(sites,rho,data,initial,es)
    expect = r.extension_terms(sites,rho,data,initial,es,large)
    check(actual == expect)
    check(wire(actual) == wire(expect))
    baseline = 0
    for site in sites:
        val = c.mask_value(site,rho,data[site.cm],c.TailWeights())
        check(val == r.mask_value(site,rho,data[site.cm],large))
        baseline += 2*((1<<min(site.log,site.row_log))-1)
    check(cache.mul_count <= baseline)
    check(cache.max_words <= max(1<<min(s.log,s.row_log) for s in sites))
    fixtures.append({'label':label,'sites':len(sites),'rho_axes':len(rho),
                     'row_logs':sorted({s.row_log for s in sites}),
                     'extension_rounds':len(es),'baseline_eq_mul':baseline,
                     'candidate_eq_mul':cache.mul_count,'builds':cache.builds,'hits':cache.hits,
                     'max_weight_words':cache.max_words,'wire_sha256':hashlib.sha256(wire(actual)).hexdigest()})

# Exact original-cube checks, arbitrary field values, Boolean challenges,
# both endpoint widths, offsets, flips, fixed values and separate extensions.
for log in range(9):
    for rowlog in sorted({0, max(0,log-1),log,log+1}):
        width = 1<<rowlog
        for mode in ('full-extension','boolean','zero-first'):
            rho = tuple(field() for _ in range(log+2))
            if mode == 'boolean': rho = tuple((i%2,0) for i in range(log+2))
            if mode == 'zero-first': rho = ((0,0),)+rho[1:]
            direct = tuple(('rho',i) for i in range(log))
            changed = direct[:-1]+(('flip',log-1),) if log else direct
            fixed = direct[:-1]+(('fixed',(7,11)),) if log else direct
            cmdata = {cm:[rng.randrange(c.P) for _ in range(18*width)] for cm in ('A','H','In','Out')}
            sites=[]
            for i,(cm,coords) in enumerate(zip(('A','H','A','H','In','Out'),
                                              (direct,direct,changed,changed,fixed,direct))):
                off = (1<<log) if log < rowlog else 0
                sites.append(c.Site(cm,rowlog,log,coords,off,2*i,i%2))
            exercise(sites,rho,cmdata,[field(),field()],label=f'small:{log}:{rowlog}:{mode}')

# One-slot reuse must still read fresh distinct masks, changed data and points.
width=32
data=[(j*j+7*j+19)%c.P for j in range(16*width)]
rho=((2,3),(5,7),(11,13),(17,19),(23,29),(31,37))
site=c.Site('A',5,3,tuple(('rho',i) for i in range(3)),8,2)
cache=c.TailWeights(); good=c.mask_value(site,rho,data,cache)
check(good == r.mask_value(site,rho,data))
check(c.mask_value(site,rho,data,cache) == good and cache.hits==1)
changed_data=list(data); changed_data[site.mask_row*width+8]+=1
fresh=c.mask_value(site,rho,changed_data,cache)
check(fresh == r.mask_value(site,rho,changed_data) and fresh != good)
changed_rho=((41,43),)+rho[1:]
fresh_point=c.mask_value(site,changed_rho,data,cache)
check(fresh_point == r.mask_value(site,changed_rho,data) and fresh_point != good)

def negative(name, wrong, expected=good):
    check(wrong != expected)
    controls.append(name)

negative('stale-mask-value-on-new-private-data',good,fresh)
negative('length-only-weight-key',good,fresh_point)
negative('reversed-coordinate-order',c.mask_value(replace(site,coords=tuple(reversed(site.coords))),rho,data,c.TailWeights()))
negative('dropped-column-offset',c.mask_value(replace(site,source_offset=0),rho,data,c.TailWeights()))
negative('wrong-row-width',c.mask_value(replace(site,row_log=4,source_offset=0),rho,data,c.TailWeights()))
negative('reused-reserved-pair',c.mask_value(replace(site,mask_row=4),rho,data,c.TailWeights()))
negative('wrong-flip-tail',c.mask_value(replace(site,coords=site.coords[:-1]+(('flip',2),)),rho,data,c.TailWeights()))
negative('wrong-fixed-coordinate',c.mask_value(replace(site,coords=site.coords[:-1]+(('fixed',(0,0)),)),rho,data,c.TailWeights()))
swapped=list(data)
swapped[2*width:3*width],swapped[3*width:4*width]=data[3*width:4*width],data[2*width:3*width]
negative('swapped-real-imag-mask-rows',c.mask_value(site,rho,swapped,c.TailWeights()))
zero_im=list(data); zero_im[3*width:4*width]=[0]*width
negative('dropped-imaginary-mask-row',c.mask_value(site,rho,zero_im,c.TailWeights()))
other=[c.Site('A',5,3,site.coords,8,2),c.Site('A',5,3,site.coords,8,4,1)]
original=[(17,19),(23,29)]; es=[(31,37),(41,43)]
term,_=c.extension_terms(other,rho,{'A':data},original,es)
negative('swapped-terminal-order',wire(term[::-1]),wire(term))
wrong,_=c.extension_terms([replace(other[0],ext_round=1),replace(other[1],ext_round=0)],rho,{'A':data},original,es)
negative('wrong-extension-family',wire(wrong),wire(term))
negative('forgot-later-zero-extension',c.add(c.mul(c.sub(c.ONE,es[0]),original[0]),c.mul(es[0],good)),term[0])
# MRU, not an unbounded cache: A,B,A causes three builds.
bounded=c.TailWeights()
for point in (rho[:3],rho[1:4],rho[:3]): bounded.get(point)
check(bounded.builds==3 and bounded.hits==0 and bounded.max_words==8)
# Equal evaluated public points are safe even when symbolic coordinates differ.
equal_rho=((2,3),(2,3))
same=c.TailWeights(); same.get(c.claim_point((('rho',0),),equal_rho)); same.get(c.claim_point((('rho',1),),equal_rho))
check(same.builds==1 and same.hits==1)

# Source-censused SC_TAB geometry: six fresh reserved pairs share rho[0..log_cols].
# These are synthetic rows at actual row lengths, not model contexts/proofs.
for log in (8,13,14):
    width=1<<log
    rho=tuple(field() for _ in range(log))
    data={cm:[rng.randrange(c.P) for _ in range(8*width)] for cm in ('A','H')}
    sites=[c.Site(cm,log,log,tuple(('rho',j) for j in range(log)),0,2*k)
           for k in range(3) for cm in ('A','H')]
    exercise(sites,rho,data,[field()],large=True,label=f'SC_TAB:{log}')
    check(fixtures[-1]['builds']==1 and fixtures[-1]['hits']==5)

cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))
result={'status':'PASS','seed':SEED,'checks':checks,'fixtures':fixtures,
        'negative_controls':controls,'elapsed_s':time.monotonic()-begin,
        'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'cpu_affinity':sorted(os.sched_getaffinity(0)),'cpu_model':cpu,
        'python':platform.python_version(),'platform':platform.platform(),
        'native_execution':False,'gpu_execution':False,'complete_verified_proofs':0,
        'complete_passes':0,'proved_positions':0,'actual_model_context':None,
        'witness_s':None,'proof_s':None,'serialization_s':None,'verification_s':None,
        'startup_s':None,'startup_fraction':None,'steady_positions_s':None,'total_positions_s':None}
Path('result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='fixtures'},indent=2))
print('fixtures',len(fixtures),'last',json.dumps(fixtures[-3:]))
