"""Source-derived public map work; no field/proof/GPU time projection."""
from pathlib import Path
from collections import Counter
import json, time, resource, statistics
import model
import legacy_catalog as base
HERE=Path(__file__).resolve().parent
start=time.monotonic();checks=0
def ck(v,label=''):
 global checks
 checks+=1
 if not v:raise AssertionError(label)
def slot_nv(g,s):
 ds=g.domains()
 dom={0:'D',1:'D',2:'T',3:'L',4:'S',14:'D',15:'Q',16:'Kv',17:'S',18:'F',19:'Tab',20:'Tab',21:'D',22:'D',23:'Dd'}
 if s in dom:return ds[dom[s]]
 if s in (5,6,7,11,12):return base.lg(g.d)
 if s==10:return base.lg(g.h*g.dh)
 if s==8:return base.lg(g.kv)+base.lg(g.dh)
 if s==9:return base.lg(g.kv)+base.lg(g.t)
 if s==13:return base.lg(g.f)
 raise ValueError(s)
def sig(p,nv):
 return (nv,tuple((kind,value if kind!='fixed' else None) for kind,value in p.coords))
def counts(key):
 nv,ops=key;lo=len(ops)//2;hi=len(ops)-lo
 return {'entries':(1<<hi)+(1<<lo),'bytes':16*((1<<hi)+(1<<lo)),
         'coordinate_visits':hi*(1<<hi)+lo*(1<<lo),'coords':len(ops)}
rows=json.loads((HERE/'native/NATIVE_LAYOUT_CENSUS.json').read_text())['rows'];seen=set();cost=[]
for row in rows:
 g=model.geometry(row);identity=(row['profile'],row['f_e'])
 if identity in seen:continue
 seen.add(identity);sites=[p for ss in base.catalog(g) for p in ss]
 cm=Counter(p.cm for p in sites)
 ck(cm['A']==row['a_sites'],'native A sites');ck(cm['H']==row['h_sites'],'native H sites');ck(cm['In']==cm['Out']==1,'endpoint sites')
 keys=[sig(p,slot_nv(g,p.slot)) for p in sites]
 for nv,ops in keys:
  ck(all(k<nv for kind,k in ops if kind!='fixed'),'moving indices in slot cube')
  ck(len({k for kind,k in ops if kind!='fixed'})==sum(kind!='fixed' for kind,k in ops),'native moving coordinates unique')
 unique=set(keys)
 per=sum(counts(k)['coordinate_visits']for k in keys)
 entries=sum(counts(k)['entries']for k in keys)
 unique_visits=sum(counts(k)['coordinate_visits']for k in unique)
 payload=sum(counts(k)['bytes']for k in unique)
 # A base-plane coefficient load per slice. H has two slices, endpoints/A one.
 private_reads=sum((2 if p.cm=='H' else 1)*(1<<p.log)for p in sites)
 outwords=sum(1<<slot_nv(g,p.slot)for p in sites)
 fixed_eq_entries=sum(1<<sum(kind=='fixed' for kind,_ in p.coords)for p in sites)
 options=[]
 for passes in [1,2,4,8]:
  native=passes*per;candidate=unique_visits
  options.append({'synthetic_resident_passes':passes,'native_map_coordinate_visits':native,'unique_plan_coordinate_visits':candidate,'map_visits_removed':native-candidate,
   'map_vector_allocations_native':passes*2*len(sites),'map_vector_allocations_planned':2*len(unique),
   'added_signature_vector_allocations':passes*len(sites),
   'fresh_private_base_reads_retained':passes*private_reads,'fresh_output_words_retained':passes*outwords,
   'fresh_fixed_eq_entries_retained':passes*fixed_eq_entries,
   'note':'Same-context independent-pass source-count model. Not native resident execution; no layer multiplicity included; all field work retained.'})
 cost.append({'profile':row['profile'],'f_e':row['f_e'],'tokens':row['tokens'],'dd':bool(g.dd),'sites':len(sites),'unique_map_signatures':len(unique),
  'per_block_map_entries':entries,'unique_map_payload_bytes':payload,
  'max_map_payload_bytes':max(counts(k)['bytes']for k in unique),'map_coordinate_visits_per_block':per,
  'unique_map_coordinate_visits':unique_visits,'private_base_reads_per_block':private_reads,'output_words_per_block':outwords,'options':options,
  'cache_cost_scope':'Map tuple payload only, excludes Vec capacities, signatures, identity keys, allocator and cache metadata; no physical memory HWM.'})

# Independent literal map-address tracing for every small subset/permutation pattern.
traces=0
for log in range(9):
 for variant in range(4):
  ops=tuple(('fixed',None)if variant==2 and j%2==0 else ('flip' if variant==1 else 'rho',log-1-j if variant==3 else j)for j in range(log))
  nv=max(1,log);lo=log//2;hi=log-lo;flo=sum(k=='fixed'for k,_ in ops[hi:])
  def half(oo,v):
   x=z=0
   for j,(k,q)in enumerate(oo):
    b=(v>>(len(oo)-1-j))&1
    if k=='fixed':z=z*2+b
    else:x|=(b if k=='rho' else 1-b)<<(nv-1-q)
   return x,z
  hm=[half(ops[:hi],i)for i in range(1<<hi)];lm=[half(ops[hi:],i)for i in range(1<<lo)]
  for i in range(1<<log):
   x=z=0
   for j,(k,q)in enumerate(ops):
    b=(i>>(log-1-j))&1
    if k=='fixed':z=(z<<1)|b
    else:x|=(b if k=='rho' else 1-b)<<(nv-1-q)
   a,b=hm[i>>lo];c,d=lm[i&((1<<lo)-1)];ck((a|c,(b<<flo)|d)==(x,z),'split/direct address trace')
  traces+=1
  ck(counts((nv,ops))['coordinate_visits']==hi*len(hm)+lo*len(lm),'literal construction operation count')

r=json.loads((HERE/'result.json').read_text());summary=[]
for b in r['bench']:
 n=statistics.median(b['native_ns']);p=statistics.median(b['planned_total_ns']);s=statistics.median(b['plan_startup_ns'])
 summary.append({'log':b['log'],'pattern':b['pattern'],'passes':b['passes'],'native_median_ns':n,'planned_median_ns':p,'helper_ratio':n/p,'helper_plan_startup_fraction':s/p,
                 'model_startup_fraction':None,'proof_rate':None})
result={'status':'PASS','checks':checks,'literal_address_trace_cases':traces,'registry_rows':len(rows),'geometries':len(cost),'elapsed_s':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 'diagnostic_faster_rows':sum(b['helper_ratio']>1 for b in summary),'diagnostic_rows':len(summary),'end_to_end_ceiling':'N/(T-C_removed_exclusive+A_added); if fraction f could be deleted freely, speedup <=1/(1-f). No exclusive map phase fraction measured.',
 'model_context':None,'model_passes':0,'proved_positions':0,'startup_fraction':None,'steady_tokens_per_s':None,'total_tokens_per_s':None,'gpu':False}
(HERE/'costs.json').write_text(json.dumps(cost,indent=2)+'\n');(HERE/'diagnostic-summary.json').write_text(json.dumps(summary,indent=2)+'\n');(HERE/'account-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
for r in cost:
 if r['tokens']==128 and 'llama-3-8b' in r['profile']:print(json.dumps({k:r[k]for k in ['profile','f_e','dd','sites','unique_map_signatures','unique_map_payload_bytes','map_coordinate_visits_per_block','unique_map_coordinate_visits','private_base_reads_per_block','output_words_per_block']}))
