"""Bounded independent algebra and native-source-schedule differential study."""
from pathlib import Path
from dataclasses import replace
from collections import Counter
import hashlib,json,random,resource,time
import catalog as m
import source_reference as ref
import candidate as c
HERE=Path(__file__).resolve().parent
SEED=202610290138
start=time.monotonic();rng=random.Random(SEED);checks=0;controls=[]
def ck(v):
    global checks
    checks+=1
    assert v,checks
def draw():return (rng.randrange(c.P),rng.randrange(c.P))
def mismatch(name,v):ck(v);controls.append(name)

# Six base registry geometries, with explicit calibration-class assumptions.
geometries=[]
for model in ['TinyLlama1.1B','Llama3-8B']:
    for t in [32,64,128]:
        row={32:12,64:13,128:14}[t] if model.startswith('Tiny') else {32:13,64:13,128:14}[t]
        geometries.append(m.Geometry(model,t,2048 if model.startswith('Tiny') else 4096,
             8192 if model.startswith('Tiny') else 16384,32,64 if model.startswith('Tiny') else 128,
             4 if model.startswith('Tiny') else 8,row,row))
for g in list(geometries):
    if g.t==128:geometries.append(replace(g,name=g.name+'-DD32',dd=32))
counts=[]
for g in geometries:
    cats=m.catalog(g);expected=ref.sites(g)
    for s,sites in enumerate(cats):
        cs=Counter(p.cm for p in sites)
        for cm in ('A','H'):ck(cs[cm]==expected.get((cm,m.NAMES[s]),0))
        ck(cs['In']+cs['Out']==int(s in (21,22)))
        ck(all(len(p.coords)==p.log and 0<=p.ext< (2 if s in (8,9) else 1) for p in sites))
    for cm in ('A','H','In','Out'):
        keys=[p.pair for ss in cats for p in ss if p.cm==cm]
        ck(len(keys)==len(set(keys)))
    for capacity in (1,2):counts.append(m.census(g,capacity))

# All slots on scaled synthetic geometries. Row sizes <=64 words and arbitrary
# inconsistent private rows; these are neither admitted shapes nor model work.
fixtures=0;native_site_checks=0;wire=hashlib.sha256();sample=None
for dd in (0,4):
 for ln,ls,lp,full in [(2,2,1,False),(4,3,2,True),(5,3,2,False)]:
  g=m.Geometry('synthetic',4,32,64,4,8,2,6,5,ln,ls,lp,full,dd)
  cats=m.catalog(g);expected=ref.sites(g)
  for s,sites in enumerate(cats):
   for cm in ('A','H'):ck(sum(p.cm==cm for p in sites)==expected.get((cm,m.NAMES[s]),0))
   for mode in ('extension','boolean','zero-first'):
    fixtures+=1
    max_axis=max([v for p in sites for k,v in p.coords if k in ('rho','flip')]+[0])+1
    rho=[draw() if mode!='boolean' else (rng.randrange(2),0) for _ in range(max_axis)]
    if mode=='zero-first':rho[0]=(0,0)
    fixed={v:draw() if mode!='boolean' else (rng.randrange(2),0) for p in sites for k,v in p.coords if k=='fixed'}
    rows={p.pair:None for p in []} # no cross-commitment alias keys
    original={};ordered=m.schedule(sites)
    for p in sites:
        width=1<<p.row
        rows[(p.cm,p.pair)]=[[rng.randrange(c.P) for _ in range(width)] for _ in range(2)]
    for cap in (1,2):
        cache=c.Cache(cap);baseline=[]
        for p in ordered:
            rr=rows[(p.cm,p.pair)];point=ref.point(p,rho,fixed)
            ck(c.tail(p,rho,fixed)==tuple(point));native_site_checks+=1
            n=1<<len(point);coefs=list(zip(rr[0][p.c0:p.c0+n],rr[1][p.c0:p.c0+n]))
            value=ref.cube(coefs,point);got=c.evaluate(p,rho,fixed,rr,cache)
            ck(got==value);baseline.append(value)
            wire.update(got[0].to_bytes(8,'little')+got[1].to_bytes(8,'little'))
            if sample is None and len(point)>=3 and mode=='extension':sample=(p,rho,fixed,rr,value)
        ck(cache.reads==sum(2*(1<<min(p.log,p.row)) for p in ordered))
        # Value equality can merge symbolic groups at Boolean points. It may
        # improve hits, never authorize an inexact symbolic cache hit.
        if mode=='extension':ck(cache.builds==m.census(g,cap)['slots'][s]['builds'])
    # Source-derived counts are independent from actual primitive call counters.
    ck(len(rows)==len(sites))

# Large native row lengths: fresh synthetic one-pair rows, independent MSB fold.
large=[]
for log in (8,13,14):
    p=m.Site(19,'A',log,log,m.rh(log),0,0,0,'large-synthetic-row')
    rho=[draw() for _ in range(log)];rr=[[rng.randrange(c.P) for _ in range(1<<log)] for _ in range(2)]
    cache=c.Cache();a=c.evaluate(p,rho,{},rr,cache);b=ref.fold(list(zip(*rr)),rho)
    ck(a==b);ck(cache.reads==2*(1<<log));large.append({'row_log':log,'words_per_row':1<<log})

# Negative controls: wrong public tail, address, pair, source, and cache epoch.
p,rho,fixed,rr,value=sample
point=c.tail(p,rho,fixed);bad=list(rho);bad[-1]=c.add(bad[-1],(1,0))
mismatch('wrong-rho-tail',c.evaluate(p,bad,fixed,rr,c.Cache())!=value)
flip=replace(p,coords=tuple(('flip',v) if k=='rho' and v==rho.__len__()-1 else (k,v) for k,v in p.coords))
mismatch('wrong-flip',c.evaluate(flip,rho,fixed,rr,c.Cache())!=value)
mismatch('swap-private-real-imag',c.evaluate(p,rho,fixed,rr[::-1],c.Cache())!=value)
rr2=[r.copy() for r in rr];rr2[0][p.c0]=(rr2[0][p.c0]+1)%c.P
mismatch('fresh-private-data-must-reread',c.evaluate(p,rho,fixed,rr2,c.Cache())!=value)
stale=c.Cache(mutation='length-only');c.evaluate(p,rho,fixed,rr,stale)
mismatch('length-only-cache-rejected',c.evaluate(p,bad,fixed,rr,stale)!=c.evaluate(p,bad,fixed,rr,c.Cache()))
mismatch('stale-private-result-rejected',value!=c.evaluate(p,rho,fixed,rr2,c.Cache()))
mismatch('wrong-tail-order',ref.cube(list(zip(*rr)),point[::-1])!=value)
q=replace(p,row=p.row-1)
mismatch('wrong-commitment-width',c.evaluate(q,rho,fixed,[r[:1<<q.row] for r in rr],c.Cache())!=value)
# Explicit nonzero c0 short slice and mismatched endpoint widths.
short=m.Site(2,'A',2,6,m.rh(2),12,99,0,'short-c0')
srho=[draw(),draw()];srr=[[rng.randrange(c.P) for _ in range(64)] for _ in range(2)]
sv=c.evaluate(short,srho,{},srr,c.Cache())
mismatch('dropping-short-c0',sv!=c.evaluate(replace(short,c0=0),srho,{},srr,c.Cache()))
# Private pair identity must never be a cache key for the resulting value.
other=[[rng.randrange(c.P) for _ in range(64)] for _ in range(2)]
sameweights=c.Cache();c.evaluate(short,srho,{},srr,sameweights)
mismatch('same-tail-new-pair-is-distinct',sv!=c.evaluate(replace(short,pair=100),srho,{},other,sameweights))
ck(sameweights.builds==1 and sameweights.hits==1 and sameweights.reads==16)
shape=(HERE/'native/hashline__src__private_block__shape.rs').read_text()
for name in m.NAMES:
    if name in ('QMM','KMM','VMM','WO','GMM','UMM','DMM'):continue
    token='a[SC_'+name+'] = ' if 'a[SC_'+name+'] = ' in shape else 'h[SC_'+name+'] = '
    mutated=shape.replace(token,token+'1 + ',1)
    g=geometries[-1] if name=='DD' else geometries[0]
    mismatch('source-site-count-'+name,ref.sites(g,mutated)!=ref.sites(g))

result={'status':'PASS','seed':SEED,'checks':checks,'fixtures':fixtures,
        'synthetic_site_comparisons':native_site_checks,'geometries':len(geometries),
        'large_synthetic_rows':large,'negative_controls':controls,
        'ordered_synthetic_values_sha256':wire.hexdigest(),
        'elapsed_s':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'full_stack_proofs':0,'model_passes':0,'proved_positions':0,
        'native_define_executed':False,'native_transcripts_verified':False}
(HERE/'counts.json').write_text(json.dumps(counts,indent=2)+'\n')
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
for x in counts:
 if x['geometry']['t']==128:print(x['geometry']['name'],x['capacity'],x['totals'])
