"""Differential public metadata, exact mask values and cost census; no full proof."""
from pathlib import Path
from dataclasses import replace
from collections import Counter
import ast,hashlib,json,random,resource,subprocess,time
import model as m
import legacy_catalog as old
import cache as c
import algebra_reference as ref
HERE=Path(__file__).resolve().parent
start=time.monotonic();SEED=202610290142;rng=random.Random(SEED)
checks=fixtures=terminals=0;controls=[];digest=hashlib.sha256()
def ck(ok,label=''):
 global checks
 checks+=1
 if not ok:raise AssertionError((checks,label))
def control(name,ok):ck(ok,name);controls.append(name)
def draw():return rng.randrange(c.P),rng.randrange(c.P)
raw=subprocess.check_output([str(HERE/'metadata')],text=True)
(HERE/'native-metadata.stdout.log').write_text(raw)
compiled={}
for line in raw.splitlines():
 h,dd,ls,*arrays=line.split('|');compiled[(bool(int(h)),int(dd),int(ls))]=[ast.literal_eval(a) for a in arrays]
ck(len(compiled)==8)
doms='T Ht L D Q Kv S F Tab Dd'.split()
rows=json.loads((HERE/'native/NATIVE_LAYOUT_CENSUS.json').read_text())['rows']
costs=[];seen=set()
for row in rows:
 g=m.geometry(row);a,h,ap,hp,look=compiled[(g.h24,g.dd,g.ls)]
 cat=old.catalog(g);counts=m.census(g);tot=counts['totals'];ds=g.domains();ps=g.planes();hs=g.helpers()
 ck(ap==[ps[d] for d in doms],'A planes')
 expected_h={**hs,'S':hs['S']+1+int(bool(g.dd)),'F':hs['F']+1,'Dd':hs['Dd']+1 if g.dd else 0,'Tab':4}
 ck(hp==[expected_h.get(d,0) for d in doms],'H planes')
 for s,ss in enumerate(cat):
  cs=Counter(x.cm for x in ss)
  ck(cs['A']==a[s],(row['profile'],s,'A'));ck(cs['H']==h[s],(s,'H'))
  ck(cs['In']+cs['Out']==int(s in (21,22)))
 ck(sum(ap)==row['a_planes']);ck(sum(hp)==row['h_planes'])
 ck(sum(a)==row['a_sites']);ck(sum(h)==row['h_sites'])
 adata=sum(n*max(1,(1<<ds[d])//row['n']) for d,n in zip(doms,ap))
 hdata=sum(2*n*max(1,(1<<ds[d])//row['n']) for d,n in zip(doms,hp))
 ck(adata==row['a_mask_base']);ck(hdata==row['h_mask_base'])
 ck(adata+2*sum(a)+2==row['a_rows']);ck(hdata+2*sum(h)+2==row['h_rows'])
 ck(sum(n*(1<<ds[d]) for d,n in zip(doms,look))==row['byte_queries'])
 ck(tot['sites']==sum(a)+sum(h)+2)
 key=(g.name,row['f_e'])
 if key in seen:continue
 seen.add(key)
 M=tot['paired3_public_sum_additions_baseline'];S=tot['prepared_public_sum_additions']
 counts['profile']=row['profile'];counts['f_e']=row['f_e'];counts['public_groups_independent']=True
 counts['costs']=dict(pair_coefficients=M,baseline_four_variable_products=4*M,
  paired3_variable_products=3*M,paired3_removed_variable_products=M,
  all_private_base_word_reads=2*M,prepared_sum_added_payload_bytes=8*max(1<<n for r in counts['slots'] for n in r['tail_logs']),
  prepared_sum_removed_additions=M-S,prepared_sum_added_logical_access_bytes=8*(3*S+M),
  prepared_sum_allocations=tot['builds'],physical_bytes=None,enclosing_time_saved=None)
 costs.append(counts)

# Every changed R13 zero-check plus the unchanged slots, with accepted metadata
# scaled to <=64 words per private row. Arbitrary private rows are synthetic.
site_comparisons=0
for h24 in (False,True):
 for dd in (0,4):
  for ls in (2,3):
   g=m.Geometry('synthetic-R13',4,32,64,4,8,2,6,5,ln=3,ls=ls,lp=2,dd=dd,h24=h24)
   for s,ss in enumerate(old.catalog(g)):
    for mode in ('extension','boolean','zero-first'):
     fixtures+=1
     axes=max([v for p in ss for k,v in p.coords if k in ('rho','flip')]+[0])+1
     rho=[(rng.randrange(2),0) if mode=='boolean' else draw() for _ in range(axes)]
     if mode=='zero-first':rho[0]=(0,0)
     fixed={v:(rng.randrange(2),0) if mode=='boolean' else draw() for p in ss for k,v in p.coords if k=='fixed'}
     rr={(p.cm,p.pair):[[rng.randrange(c.P) for _ in range(1<<p.row)] for _ in range(2)] for p in ss}
     values={};cache=c.Cache()
     for p in old.schedule(ss):
      point=ref.point(p,rho,fixed);data=rr[p.cm,p.pair];n=1<<len(point)
      value=ref.cube(list(zip(data[0][p.c0:p.c0+n],data[1][p.c0:p.c0+n])),point)
      ck(c.evaluate(p,rho,fixed,data,cache)==value);site_comparisons+=1;values[p.cm,p.pair]=value
      digest.update(repr(value).encode())
     ck(cache.reads==sum(2*(1<<len(p.tail)) for p in ss))
     if mode=='extension':ck(cache.builds==m.census(g)['slots'][s]['builds'])
     # Exact recurrence at one/two extension coordinates, including later
     # zero injection. No mock transcript hash is called a receipt.
     es=[draw() for _ in range(2 if s in (8,9) else 1)];initial=[draw() for _ in ss];cur=initial.copy()
     for ext,e in enumerate(es):
      for j,p in enumerate(ss):cur[j]=c.add(c.mul(c.sub((1,0),e),cur[j]),c.mul(e,values[p.cm,p.pair] if p.ext==ext else (0,0)))
     for j,p in enumerate(ss):
      keep=(1,0);coeff=es[p.ext]
      for e in es:keep=ref.times(keep,ref.comp(e))
      for e in es[p.ext+1:]:coeff=ref.times(coeff,ref.comp(e))
      ck(cur[j]==ref.plus(ref.times(keep,initial[j]),ref.times(coeff,values[p.cm,p.pair])));terminals+=1

# Exact actual-width, short-offset, source/point/order/freshness controls.
for log in (0,8,14):
 p=old.Site(19,'A',log,log,old.rh(log),0,0,0,'large-synthetic');rho=[draw() for _ in range(log)]
 rr=[[rng.randrange(c.P) for _ in range(1<<log)] for _ in range(2)]
 ck(c.evaluate(p,rho,{},rr,c.Cache())==ref.fold(list(zip(*rr)),rho))
control('legacy-8B-census-undercounts-current-R13',next(x for x in costs if 'llama-3-8b-t128-lh24-v1' in x['profile'] and x['f_e']==12)['totals']['sites']>174)
p=old.Site(2,'A',3,6,old.rh(3),12,99,0,'offset');rho=[draw() for _ in range(3)];rr=[[rng.randrange(c.P) for _ in range(64)] for _ in range(2)]
value=c.evaluate(p,rho,{},rr,c.Cache());changed=[r.copy() for r in rr];changed[0][12]=(changed[0][12]+1)%c.P
control('private-freshness',c.evaluate(p,rho,{},changed,c.Cache())!=value)
control('offset-kept',c.evaluate(replace(p,c0=0),rho,{},rr,c.Cache())!=value)
control('ordered-tail',c.evaluate(p,rho[::-1],{},rr,c.Cache())!=value)
control('real-imag-kept',c.evaluate(p,rho,{},rr[::-1],c.Cache())!=value)
changedrho=rho.copy();changedrho[0]=c.add(changedrho[0],(1,0));stale=c.Cache(mutation='length-only');c.evaluate(p,rho,{},rr,stale)
control('length-only-cache',c.evaluate(p,changedrho,{},rr,stale)!=c.evaluate(p,changedrho,{},rr,c.Cache()))
control('leading-Ht-versus-score-tail',old.Site(17,'A',3,6,old.rh(3),0,1,0,'Ht').tail!=old.Site(17,'A',7,6,old.rh(7),0,2,0,'S').tail)
control('RoPE-flip',c.evaluate(replace(p,coords=(('flip',0),)+p.coords[1:]),rho,{},rr,c.Cache())!=value)
e0,e1,initial=draw(),draw(),draw()
proper=ref.plus(ref.times(ref.times(ref.comp(e0),ref.comp(e1)),initial),ref.times(ref.times(e0,ref.comp(e1)),value))
wrong=ref.plus(ref.times(ref.times(ref.comp(e0),ref.comp(e1)),initial),ref.times(e0,value))
control('later-zero-extension',proper!=wrong)
result=dict(status='PASS',seed=SEED,checks=checks,fixtures=fixtures,synthetic_site_comparisons=site_comparisons,independent_extension_terminals=terminals,
 native_metadata_cases=len(compiled),native_census_rows_checked=len(rows),distinct_profile_context_precision_rows=len(costs),negative_controls=controls,
 synthetic_digest=digest.hexdigest(),elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 full_stack_proofs=0,model_passes=0,proved_positions=0,native_metadata_methods_executed=True,native_constructor_or_define_executed=False,native_receipts_verified=False)
(HERE/'counts.json').write_text(json.dumps(costs,indent=2)+'\n');(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
